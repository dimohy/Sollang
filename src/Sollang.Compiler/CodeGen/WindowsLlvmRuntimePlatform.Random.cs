using System.Text;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class WindowsLlvmRuntimePlatform
{
    public override void EmitSecureRandomPrimitives(StringBuilder functions)
    {
        functions.AppendLine("declare dllimport i32 @BCryptGenRandom(ptr, ptr, i32, i32)");
        functions.AppendLine("""
            define internal i1 @sollang_secure_random_fill(ptr %buffer, i64 %length) #0 {
            entry:
              %empty = icmp eq i64 %length, 0
              br i1 %empty, label %success, label %fill

            fill:
              %offset = phi i64 [ 0, %entry ], [ %next_offset, %continue ]
              %remaining = sub i64 %length, %offset
              %large = icmp ugt i64 %remaining, 4294967295
              %chunk64 = select i1 %large, i64 4294967295, i64 %remaining
              %chunk = trunc i64 %chunk64 to i32
              %target = getelementptr i8, ptr %buffer, i64 %offset
              %status = call i32 @BCryptGenRandom(ptr null, ptr %target, i32 %chunk, i32 2)
              %ok = icmp eq i32 %status, 0
              br i1 %ok, label %continue, label %failure

            continue:
              %next_offset = add i64 %offset, %chunk64
              %done = icmp eq i64 %next_offset, %length
              br i1 %done, label %success, label %fill

            success:
              ret i1 true

            failure:
              ret i1 false
            }

            """);
    }
}
