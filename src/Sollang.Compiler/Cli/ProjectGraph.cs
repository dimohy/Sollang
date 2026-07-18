using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Cli;

internal sealed record ProjectBuild(
    ProjectPackage RootPackage,
    ProjectProduct Product,
    IReadOnlyList<ProjectPackage> Packages)
{
    public static ProjectBuild Load(string pathOrDirectory, string? productName)
    {
        var rootManifest = ProjectManifest.Load(pathOrDirectory);
        var manifestsByPath = new Dictionary<string, ProjectPackage>(StringComparer.OrdinalIgnoreCase);
        var manifestsByName = new Dictionary<string, string>(StringComparer.Ordinal);
        var states = new Dictionary<string, VisitState>(StringComparer.OrdinalIgnoreCase);
        var root = LoadPackage(
            rootManifest,
            rootManifest.SelectProduct(productName),
            manifestsByPath,
            manifestsByName,
            states,
            []);
        return new ProjectBuild(
            root,
            root.Product,
            manifestsByPath.Values
                .OrderBy(static package => package.Manifest.Name, StringComparer.Ordinal)
                .ToArray());
    }

    private static ProjectPackage LoadPackage(
        ProjectManifest manifest,
        ProjectProduct product,
        IDictionary<string, ProjectPackage> packagesByPath,
        IDictionary<string, string> pathsByName,
        IDictionary<string, VisitState> states,
        IReadOnlyList<string> chain)
    {
        if (states.TryGetValue(manifest.Path, out var state))
        {
            if (state == VisitState.Visiting)
            {
                throw new SollangException(
                    "project dependency cycle: " + string.Join(" -> ", chain.Append(manifest.Name)));
            }
            return packagesByPath[manifest.Path];
        }

        if (pathsByName.TryGetValue(manifest.Name, out var existingPath)
            && !StringComparer.OrdinalIgnoreCase.Equals(existingPath, manifest.Path))
        {
            throw new SollangException(
                $"project name '{manifest.Name}' is declared by both '{existingPath}' and '{manifest.Path}'");
        }
        pathsByName[manifest.Name] = manifest.Path;
        states[manifest.Path] = VisitState.Visiting;

        var dependencies = new Dictionary<string, ProjectPackage>(StringComparer.Ordinal);
        var nextChain = chain.Append(manifest.Name).ToArray();
        foreach (var dependency in manifest.Dependencies.OrderBy(static pair => pair.Key, StringComparer.Ordinal))
        {
            var dependencyManifest = ProjectManifest.Load(dependency.Value);
            if (!string.Equals(dependency.Key, dependencyManifest.Name, StringComparison.Ordinal))
            {
                throw new SollangException(
                    $"dependency '{dependency.Key}' resolves to project '{dependencyManifest.Name}' in '{dependencyManifest.Path}'");
            }
            dependencies.Add(
                dependency.Key,
                LoadPackage(
                    dependencyManifest,
                    dependencyManifest.SelectProduct(dependencyManifest.Name),
                    packagesByPath,
                    pathsByName,
                    states,
                    nextChain));
        }

        var package = new ProjectPackage(manifest, product, dependencies);
        packagesByPath[manifest.Path] = package;
        states[manifest.Path] = VisitState.Visited;
        return package;
    }

    private enum VisitState
    {
        Visiting,
        Visited
    }
}

internal sealed record ProjectPackage(
    ProjectManifest Manifest,
    ProjectProduct Product,
    IReadOnlyDictionary<string, ProjectPackage> Dependencies)
{
    public string SourceRoot => Path.GetDirectoryName(Product.RootSource)
        ?? System.IO.Directory.GetCurrentDirectory();
}
