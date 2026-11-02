using System;
using System.Text.Json;

Console.WriteLine(JsonSerializer.Serialize(new { processors = Environment.ProcessorCount, runtime = Environment.Version.ToString() }));
