using Sollang.Compiler.Browser;

var cases = new[]
{
    (
        "hello",
        """
        main {
            "Hello from Sollang!" -> println
        }
        """,
        "Hello from Sollang!\n"
    ),
    (
        "array",
        """
        main {
            [3, 5, 8, 13, 21] => values
            0 => total!
            values -> each value {
                total! + value => total!
            }
            "total=$(total!)" -> println
        }
        """,
        "total=50\n"
    ),
    (
        "stream",
        """
        import std.sequence

        main {
            0 => scanned!
            1..1000000000
                -> map value {
                    value
                }
                -> tap value {
                    scanned! + 1 => scanned!
                }
                -> filter value {
                    value % 7 == 0
                }
                -> take(3)
                -> each value {
                    "$value" -> println
                }
            "scanned=$(scanned!)" -> println
        }
        """,
        "7\n14\n21\nscanned=21\n"
    ),
    (
        "sensor",
        """
        import std.sequence

        struct Reading {
            sensorId: Int
            celsius: Int
        }

        main {
            0 => scanned!
            1..1000000000
                -> map sensorId {
                    Reading {
                        sensorId: sensorId
                        celsius: 20 + ((sensorId % 97) * 17) % 40
                    }
                }
                -> tap reading {
                    reading.sensorId => scanned!
                }
                -> filter reading {
                    reading.celsius >= 57
                }
                -> take(5)
                -> each alert {
                    "sensor $(alert.sensorId)=$(alert.celsius)" -> println
                }
            "scanned=$(scanned!)" -> println
        }
        """,
        "sensor 7=59\nsensor 14=58\nsensor 21=57\nsensor 47=59\nsensor 54=58\nscanned=54\n"
    ),
    (
        "scan",
        """
        import std.sequence

        struct Transaction {
            id: Int
            amount: Int
        }

        struct AccountState {
            lastId: Int
            withdrawn: Int
        }

        main {
            0 => scanned!
            1..1000000000
                -> map id {
                    Transaction {
                        id: id
                        amount: 100 + (id % 7) * 50
                    }
                }
                -> tap transaction {
                    scanned! + 1 => scanned!
                }
                -> scan(AccountState {
                    lastId: 0
                    withdrawn: 0
                }) account, transaction {
                    AccountState {
                        lastId: transaction.id
                        withdrawn: account.withdrawn + transaction.amount
                    }
                }
                -> filter account {
                    account.withdrawn > 1000
                }
                -> take(5)
                -> each warning {
                    "$(warning.lastId):$(warning.withdrawn)" -> println
                }
            "scanned=$(scanned!)" -> println
        }
        """,
        "5:1250\n6:1650\n7:1750\n8:1900\n9:2100\nscanned=9\n"
    )
};

var failed = 0;
foreach (var (name, source, expected) in cases)
{
    var result = BrowserPlaygroundCompiler.CompileAndRun(source);
    if (!result.Success || result.Output != expected)
    {
        failed++;
        Console.Error.WriteLine($"FAIL {name}");
        Console.Error.WriteLine(result.Diagnostics);
        Console.Error.WriteLine($"EXPECTED:\n{expected}\nACTUAL:\n{result.Output}");
    }
    else
    {
        Console.WriteLine($"PASS {name}");
    }
}

return failed == 0 ? 0 : 1;
