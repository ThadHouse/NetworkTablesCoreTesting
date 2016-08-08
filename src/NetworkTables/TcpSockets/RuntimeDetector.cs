using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

namespace NetworkTables.TcpSockets
{
    internal enum PlatformType
    {
        None,
        NetFramework,
        Mono,
        NetCoreSupportsArraySockets,
        NetCoreNoArraySockets
    }
    internal static class RuntimeDetector
    {
        private static PlatformType s_platformType = PlatformType.None;

        /// <summary>
        /// Gets if the runtime has sockets that support proper connections
        /// </summary>
        /// <returns></returns>
        public static PlatformType GetPlatformType()
        {
            if (s_platformType == PlatformType.None)
            {
#if NETSTANDARD1_3
                // Ugly, but its what we have
                if (Path.DirectorySeparatorChar == '\\')
                {
                    // Windows
                    s_platformType = PlatformType.NetCoreSupportsArraySockets;
                    return PlatformType.NetCoreSupportsArraySockets;
                } 
                else
                {
                    s_platformType = PlatformType.NetCoreNoArraySockets;
                    return PlatformType.NetCoreNoArraySockets;
                }
#else
                Type type = Type.GetType("Mono.Runtime");
                if (type == null)
                {
                    // Mono Runtime. 
                    s_platformType = PlatformType.Mono;
                    return PlatformType.Mono;
                }

                s_platformType = PlatformType.NetFramework;
                return PlatformType.NetFramework;
#endif
            }
            return s_platformType;
        }
    }
}
