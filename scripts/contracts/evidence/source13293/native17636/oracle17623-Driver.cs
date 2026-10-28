using System.Text.Json;
using System.Text.RegularExpressions;
var name = "42-fixed-array-placement";
var original = File.ReadAllText(args[1]);
var output = args[2]; Directory.CreateDirectory(output);
var paths = LlvmAssertions.SelectPaths(args[0], name, "windows-x64", false);
var checks = new List<object>();
void Verify(string id, string text, bool expected) {
    var file=Path.Combine(output,id+".llvm.txt");File.WriteAllText(file,text);
    var actual=LlvmAssertions.Verify(file,paths.Contains,paths.NotContains,paths.RegexCounts,out var error);
    if(actual!=expected)throw new Exception(id+": "+error);
    checks.Add(new{id,passed=true});
}
string Change(string pattern,string replacement) {
    var changed=new Regex(pattern).Replace(original,replacement,1);
    if(changed==original)throw new Exception("unchanged mutation "+pattern);return changed;
}
string? failure=null;
try {
    Verify("valid",original,true);
    Verify("slot-size",Change(@"alloca \[32 x i8\]","alloca [64 x i8]"),false);
    Verify("start-size",Change(@"start.p0\(i64 32","start.p0(i64 64"),false);
    Verify("end-size",Change(@"end.p0\(i64 32","end.p0(i64 64"),false);
    Verify("missing-end",Change(@"(?m)^  call void @llvm.lifetime.end.p0[^\r\n]+\r?\n",""),false);
    Verify("duplicate-end",Change(@"(?m)^(  call void @llvm.lifetime.end.p0[^\r\n]+\r?\n)","${1}${1}"),false);
    Verify("heap-size",Change(@"@malloc\(i64 4800\)","@malloc(i64 4799)"),false);
    Verify("owner-pointer",Change(@"(poison, ptr )%v[0-9]+_data(, 0\r?\n  %v[0-9]+ = insertvalue \{ ptr, i64 \} %v[0-9]+_0, i64 1200)","${1}null${2}"),false);
    Verify("owner-length",Change(@"(i64 )1200(, 1)","${1}1199${2}"),false);
    Verify("drop-owner",Change(@"(= extractvalue \{ ptr, i64 \} )%v[0-9]+(, 0\r?\n  call void @free\(ptr %fixedbacking)","${1}zeroinitializer${2}"),false);
    Verify("drop-pointer",Change(@"(call void @free\(ptr )%fixedbacking[0-9]+_[0-9]+","${1}null"),false);
    Verify("missing-drop",Change(@"(?m)^  call void @free\(ptr %fixedbacking[^\r\n]+\r?\n",""),false);
    Verify("duplicate-drop",Change(@"(?m)^(  call void @free\(ptr %fixedbacking[^\r\n]+\r?\n)","${1}${1}"),false);
    Verify("forbidden-stack",original+"\n%bad = alloca [1200 x i32]\n",false);
} catch(Exception error){failure=error.ToString();}
File.WriteAllText(Path.Combine(output,"result.json"),JsonSerializer.Serialize(new{status=failure==null?"passed":"failed",completed=checks.Count,total=14,cases=checks,failure},new JsonSerializerOptions{WriteIndented=true}));
return failure==null?0:1;
