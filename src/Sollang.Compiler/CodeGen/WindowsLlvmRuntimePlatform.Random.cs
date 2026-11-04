using System.Text;
using Sollang.Compiler.Shared;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class WindowsLlvmRuntimePlatform
{
    public override void EmitSecureRandomPrimitives(StringBuilder functions)
    {
        functions.AppendLine(NativeRuntimePolicy.SecureRandomWindowsPlatformDefinitions());
    }
}
