namespace Sollang.Compiler;

internal enum TargetArchitecture
{
    X86_64,
    Arm64,
    Wasm32
}

internal enum CpuDispatchPolicy
{
    BaselineOnly,
    RuntimeDetect,
    FixedFeatures
}

[Flags]
internal enum TargetFeature : ulong
{
    None = 0,
    Sse2 = 1UL << 0,
    Sse42 = 1UL << 1,
    Pclmulqdq = 1UL << 2,
    Aes = 1UL << 3,
    Sha = 1UL << 4,
    Avx = 1UL << 5,
    Avx2 = 1UL << 6,
    Bmi2 = 1UL << 7,
    Vaes = 1UL << 8,
    Vpclmulqdq = 1UL << 9,
    Neon = 1UL << 16,
    Pmull = 1UL << 17,
    Sha2 = 1UL << 18,
    Crc = 1UL << 19,
    Simd128 = 1UL << 24
}

internal readonly record struct TargetContract(
    TargetArchitecture Architecture,
    CpuDispatchPolicy DispatchPolicy,
    TargetFeature RequiredFeatures,
    TargetFeature AllowedFeatures,
    TargetFeature ForbiddenFeatures)
{
    private const TargetFeature X86Optional =
        TargetFeature.Sse42 |
        TargetFeature.Pclmulqdq |
        TargetFeature.Aes |
        TargetFeature.Sha |
        TargetFeature.Avx |
        TargetFeature.Avx2 |
        TargetFeature.Bmi2 |
        TargetFeature.Vaes |
        TargetFeature.Vpclmulqdq;

    public static TargetContract For(CompilationTarget target) => target switch
    {
        CompilationTarget.WindowsX64 or CompilationTarget.LinuxX64 => new(
            TargetArchitecture.X86_64,
            CpuDispatchPolicy.RuntimeDetect,
            TargetFeature.Sse2,
            X86Optional,
            TargetFeature.None),
        CompilationTarget.Wasm32Browser => new(
            TargetArchitecture.Wasm32,
            CpuDispatchPolicy.BaselineOnly,
            TargetFeature.None,
            TargetFeature.None,
            TargetFeature.None),
        _ => throw new ArgumentOutOfRangeException(nameof(target), target, null)
    };

    public string CacheKey
    {
        get
        {
            var policy = DispatchPolicy switch
            {
                CpuDispatchPolicy.BaselineOnly => "b",
                CpuDispatchPolicy.RuntimeDetect => "d",
                CpuDispatchPolicy.FixedFeatures => "f",
                _ => throw new ArgumentOutOfRangeException(nameof(DispatchPolicy))
            };
            return string.Create(
                System.Globalization.CultureInfo.InvariantCulture,
                $"cpu1-{policy}-r{(ulong)RequiredFeatures:x}-a{(ulong)AllowedFeatures:x}-f{(ulong)ForbiddenFeatures:x}");
        }
    }
}
