using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Cli;

internal sealed record ProjectBuild(
    ProjectPackage RootPackage,
    ProjectProduct Product,
    IReadOnlyList<ProjectPackage> Packages,
    WorkspaceManifest? Workspace)
{
    public static ProjectBuild LoadProject(string pathOrDirectory, string? productName)
    {
        var rootManifest = ProjectManifest.Load(pathOrDirectory);
        return Load(rootManifest, productName, workspace: null);
    }

    public static ProjectBuild LoadWorkspace(
        string pathOrDirectory,
        string? packageName,
        string? productName)
    {
        var workspace = WorkspaceManifest.Load(pathOrDirectory);
        var rootManifest = workspace.SelectMember(packageName);
        return Load(rootManifest, productName, workspace, includeAllWorkspaceMembers: true);
    }

    public static ProjectBuild LoadWorkspaceForResolution(string pathOrDirectory)
    {
        var workspace = WorkspaceManifest.Load(pathOrDirectory);
        var rootManifest = workspace.Members[0];
        return Load(rootManifest, rootManifest.Name, workspace, includeAllWorkspaceMembers: true);
    }

    public static ProjectBuild LoadProjectForResolution(string pathOrDirectory)
    {
        var manifest = ProjectManifest.Load(pathOrDirectory);
        var product = manifest.Products.ContainsKey(manifest.Name)
            ? manifest.Name
            : manifest.Products.Keys.Order(StringComparer.Ordinal).First();
        return Load(manifest, product, workspace: null);
    }

    private static ProjectBuild Load(
        ProjectManifest rootManifest,
        string? productName,
        WorkspaceManifest? workspace,
        bool includeAllWorkspaceMembers = false)
    {
        var manifestsByPath = new Dictionary<string, ProjectPackage>(StringComparer.OrdinalIgnoreCase);
        var manifestsByName = new Dictionary<string, string>(StringComparer.Ordinal);
        var states = new Dictionary<string, VisitState>(StringComparer.OrdinalIgnoreCase);
        var workspaceMembers = workspace?.Members.ToDictionary(
            static member => member.Path,
            StringComparer.OrdinalIgnoreCase);
        var root = LoadPackage(
            rootManifest,
            rootManifest.SelectProduct(productName),
            manifestsByPath,
            manifestsByName,
            states,
            workspaceMembers,
            []);
        if (includeAllWorkspaceMembers)
        {
            foreach (var member in workspace!.Members)
            {
                if (manifestsByPath.ContainsKey(member.Path))
                {
                    continue;
                }
                var memberProduct = member.Products.TryGetValue(member.Name, out var memberRoot)
                    ? new ProjectProduct(member.Name, memberRoot)
                    : new ProjectProduct(
                        member.Products.Keys.Order(StringComparer.Ordinal).First(),
                        member.Products.OrderBy(static pair => pair.Key, StringComparer.Ordinal).First().Value);
                LoadPackage(
                    member,
                    memberProduct,
                    manifestsByPath,
                    manifestsByName,
                    states,
                    workspaceMembers,
                    []);
            }
        }
        return new ProjectBuild(
            root,
            root.Product,
            manifestsByPath.Values
                .OrderBy(static package => package.Manifest.Name, StringComparer.Ordinal)
                .ToArray(),
            workspace);
    }

    private static ProjectPackage LoadPackage(
        ProjectManifest manifest,
        ProjectProduct product,
        IDictionary<string, ProjectPackage> packagesByPath,
        IDictionary<string, string> pathsByName,
        IDictionary<string, VisitState> states,
        IReadOnlyDictionary<string, ProjectManifest>? workspaceMembers,
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
            var dependencyManifest = ProjectManifest.Load(dependency.Value.Path);
            if (workspaceMembers is not null
                && !workspaceMembers.ContainsKey(dependencyManifest.Path))
            {
                throw new SollangException(
                    $"workspace package '{manifest.Name}' depends on '{dependencyManifest.Name}' "
                    + $"at '{dependencyManifest.Path}', but that project is not a workspace member");
            }
            if (!string.Equals(dependency.Key, dependencyManifest.Name, StringComparison.Ordinal))
            {
                throw new SollangException(
                    $"dependency '{dependency.Key}' resolves to project '{dependencyManifest.Name}' in '{dependencyManifest.Path}'");
            }
            if (!dependency.Value.Version.Accepts(dependencyManifest.Version))
            {
                throw new SollangException(
                    $"dependency '{dependency.Key}' requires version '{dependency.Value.Version.Text}', "
                    + $"but project '{dependencyManifest.Name}' declares '{dependencyManifest.Version}'");
            }
            dependencies.Add(
                dependency.Key,
                LoadPackage(
                    dependencyManifest,
                    dependencyManifest.SelectProduct(dependencyManifest.Name),
                    packagesByPath,
                    pathsByName,
                    states,
                    workspaceMembers,
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
    public string Identity => $"{Manifest.Name}@{Manifest.Version}";

    public string SourceRoot => Path.GetDirectoryName(Product.RootSource)
        ?? System.IO.Directory.GetCurrentDirectory();
}
