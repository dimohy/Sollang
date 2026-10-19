using System.Collections;
using System.Reflection;
using System.Runtime.Loader;
using System.Security.Cryptography;
using System.Text.Json;

internal static class ContainerElementAlignmentTests
{
    public static int Run(string compilerPath, string resultPath)
    {
        compilerPath = Path.GetFullPath(compilerPath);
        var context = new AssemblyLoadContext("container-element-alignment", isCollectible: true);
        var assembly = context.LoadFromAssemblyPath(compilerPath);
        var tableType = assembly.GetType("Sollang.Compiler.Semantics.TypeDefinitionTable", true)!;
        var idType = assembly.GetType("Sollang.Compiler.Semantics.TypeId", true)!;
        var constructor = tableType.GetConstructors().Single();
        object Id(int value) => Enum.ToObject(idType, value);
        object Call(object target, string name, params object?[] values) =>
            target.GetType().GetMethod(name)!.Invoke(target, values)!;
        int Read(object target, string name) => Convert.ToInt32(target.GetType().GetProperty(name)!.GetValue(target));
        object Table()
        {
            var parameters = constructor.GetParameters();
            var values = new object?[parameters.Length];
            for (var i = 0; i < 5; i++)
                values[i] = Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(parameters[i].ParameterType.GetGenericArguments()));
            values[5] = 8;
            return constructor.Invoke(values);
        }
        object Map(object key, object value)
        {
            var map = (IDictionary)Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(idType, value.GetType()))!;
            map.Add(key, value);
            return map;
        }
        object Pair(object type, int count, bool nullable = false) => Activator.CreateInstance(
            typeof(ValueTuple<,>).MakeGenericType(idType, nullable ? typeof(int?) : typeof(int)), [type, count])!;
        var rows = new List<object>();
        var passed = 0;
        var methods = new[] { "static", "fixed", "register-static", "register-fixed", "dynamic", "register-dynamic", "register-dynamics", "bounded", "register-bounded", "dictionary", "heap", "deque", "set" };
        foreach (var shape in new[] { (Name: "bytes3", Scalar: "UInt8", Count: 3, Size: 3, Alignment: 1),
                     (Name: "words3", Scalar: "Int", Count: 3, Size: 12, Alignment: 4),
                     (Name: "scalar", Scalar: "Int", Count: 1, Size: 4, Alignment: 4) })
        foreach (var method in methods)
        {
            var table = Table();
            var element = Enum.Parse(idType, shape.Scalar);
            if (shape.Count > 1)
            {
                var fieldType = typeof(ValueTuple<,>).MakeGenericType(typeof(string), idType);
                var fields = Array.CreateInstance(fieldType, shape.Count);
                for (var i = 0; i < shape.Count; i++)
                    fields.SetValue(Activator.CreateInstance(fieldType, [null, element]), i);
                element = Call(table, "GetOrAddProduct", fields, shape.Name, 1, 1);
            }
            string? failure = null;
            try
            {
                if (Convert.ToInt32(Call(table, "InlineSizeOf", element)) != shape.Size
                    || Convert.ToInt32(Call(table, "AlignmentOf", element)) != shape.Alignment)
                    throw new InvalidOperationException("Aggregate fixture layout differs from the ABI expectation.");
                var id = Id(900000);
                string getter;
                switch (method)
                {
                    case "static": id = Call(table, "GetOrAddStaticArray", element); getter = "GetStaticArray"; break;
                    case "fixed": id = Call(table, "GetOrAddFixedStaticArray", element, 2); getter = "GetStaticArray"; break;
                    case "register-static": Call(table, "RegisterStaticArrays", Map(id, Pair(element, 2, true))); getter = "GetStaticArray"; break;
                    case "register-fixed": Call(table, "RegisterFixedStaticArrays", Map(id, Pair(element, 2))); getter = "GetStaticArray"; break;
                    case "dynamic": id = Call(table, "GetOrAddDynamicArray", element); getter = "GetDynamicArray"; break;
                    case "register-dynamic": Call(table, "RegisterDynamicArray", id, element); getter = "GetDynamicArray"; break;
                    case "register-dynamics": Call(table, "RegisterDynamicArrays", Map(id, element)); getter = "GetDynamicArray"; break;
                    case "bounded": id = Call(table, "GetOrAddBoundedArray", element, 2); getter = "GetBoundedArray"; break;
                    case "register-bounded": Call(table, "RegisterBoundedArrays", Map(id, Pair(element, 2))); getter = "GetBoundedArray"; break;
                    case "dictionary": id = Call(table, "GetOrAddDictionary", element, element); getter = "GetDictionary"; break;
                    case "heap": id = Call(table, "GetOrAddBinaryHeap", element); getter = "GetDynamicArray"; break;
                    case "deque": id = Call(table, "GetOrAddDeque", element); getter = "GetDynamicArray"; break;
                    default: id = Call(table, "GetOrAddSet", element); getter = "GetDictionary"; break;
                }
                var definition = Call(table, getter, id);
                var alignment = Read(definition, getter == "GetDictionary" ? "KeyAlignment" : "ElementAlignment");
                if (alignment != shape.Alignment || (alignment & (alignment - 1)) != 0)
                    throw new InvalidOperationException($"Element alignment {alignment}; expected {shape.Alignment}.");
                if (method == "dictionary" && Read(definition, "ValueAlignment") != shape.Alignment)
                    throw new InvalidOperationException("Dictionary value alignment differs from the ABI expectation.");
                passed++;
            }
            catch (Exception error) { failure = error.InnerException?.Message ?? error.Message; }
            rows.Add(new { id = shape.Name + "/" + method, status = failure is null ? "passed" : "failed", failure });
        }
        var success = passed == rows.Count;
        File.WriteAllText(resultPath, JsonSerializer.Serialize(new
        {
            schemaVersion = 1, status = success ? "passed" : "failed", completed = passed, total = rows.Count,
            compiler = compilerPath, loadedCompiler = assembly.Location,
            compilerSha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(compilerPath))), cases = rows,
            claimsGoalComplete = false
        }, new JsonSerializerOptions { WriteIndented = true }) + "\n");
        Console.WriteLine($"[container element alignment] {(success ? "PASS" : "FAIL")} {passed}/{rows.Count}");
        context.Unload();
        return success ? 0 : 1;
    }
}
