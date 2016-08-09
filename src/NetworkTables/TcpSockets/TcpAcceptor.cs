using System;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using static NetworkTables.Logging.Logger;

namespace NetworkTables.TcpSockets
{
    internal class TcpAcceptor : INetworkAcceptor
    {
        private static int num = 0;

        private TcpListener m_server;

        private readonly int m_port;
        private readonly string m_address;

        private bool m_shutdown;
        private bool m_listening;

        private int localNum;

        private CancellationTokenSource m_tokenSource;

        public TcpAcceptor(int port, string address)
        {
            m_port = port;
            m_address = address;
            Console.WriteLine($"Creating Num {num}");
            localNum = num;
            num++;
        }

        public int Start()
        {
            Console.WriteLine($"Starting Num {localNum}");
            if (m_listening) return 0;

            m_tokenSource = new CancellationTokenSource();

            var address = !string.IsNullOrEmpty(m_address) ? IPAddress.Parse(m_address) : IPAddress.Any;

            m_server = new TcpListener(address, m_port);

            try
            {
                m_server.Start(5);
            }
            catch (SocketException ex)
            {
                Error($"{localNum} TcpListener Start(): failed {ex.SocketErrorCode}");
                Console.WriteLine(ex.StackTrace);
                return (int)ex.SocketErrorCode;
            }

            m_listening = true;
            return 0;
        }

        public void Shutdown()
        {
            Console.WriteLine($"Shutdown Num {localNum}");
            m_shutdown = true;

            m_tokenSource?.Cancel();

            m_server?.Stop();
            m_server = null;
            m_tokenSource = null;
            m_listening = false;

            /*

            //Force wakeup with non-blocking connect to ourselves
            var address = !string.IsNullOrEmpty(m_address) ? IPAddress.Parse(m_address) : IPAddress.Loopback;

            Socket connectSocket;
            try
            {
                connectSocket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            }
            catch (SocketException)
            {
                return;
            }

            connectSocket.Blocking = false;

            try
            {
                connectSocket.Connect(address, m_port);
                connectSocket.Dispose();
            }
            catch (SocketException)
            {
            }

            m_listening = false;
            m_server?.Stop();
            m_server = null;
            */
        }

        public TcpClient Accept()
        {
            if (!m_listening || m_shutdown) return null;

            var tokenSource = m_tokenSource;

            if (tokenSource == null || tokenSource.IsCancellationRequested)
                return null;
            try
            {
                var task = m_server.AcceptTcpClientAsync();
                task.Wait(tokenSource.Token);
                if (task.IsCompleted)
                {
                    return task.Result;
                }
                else
                {
                    return null;
                }
            }
            catch (AggregateException)
            {
                // TODO: Figure out how to handle this
                return null;
            }
            catch (OperationCanceledException)
            {
                return null;
            }
            catch (ObjectDisposedException)
            {
                return null;
            }

            /*
            SocketError error;
            Socket socket = m_server.Accept(out error);
            if (socket == null)
            {
                if (!m_shutdown) Error($"Accept() failed: {error}");
                return null;
            }
            if (m_shutdown)
            {
                socket.Dispose();
                return null;
            }
            return new TcpClient(0);
            */
        }
    }
}
