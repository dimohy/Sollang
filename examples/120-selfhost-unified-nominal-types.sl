import smalllang.compiler.semantic.nominal_types as nominalTypes

main {
    ["namespace sample.math\npublic struct Number { }", "namespace app.main\nimport sample.math as math\nstruct Local {\ncount: Int\n}\nstruct Uses {\nlocal: Local\nremote: math.Number\nmissing: Unknown\n}", ~] => sources!
    sources! -> nominalTypes.resolve => resolved!
    resolved! -> each item {
        item.sourceModule == 1 -> if {
            "nominal = $(item.origin),$(item.targetModule),$(item.targetSymbol),$(item.status)" -> println
        }
    }
}
