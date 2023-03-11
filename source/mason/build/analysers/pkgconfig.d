/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.analysers.pkgconfig;
 *
 * pkgconfig files
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.build.analysers.pkgconfig;

import std.algorithm : canFind;
import std.experimental.logger;
import std.path : dirName, baseName;
import std.string : endsWith, format;
public import moss.deps.analysis;

/**
 * Does this look like a valid pkgconfig file?
 */
public AnalysisReturn acceptPkgconfigFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    auto filename = fileInfo.path;
    auto directory = filename.dirName;

    if (!directory.canFind("/pkgconfig") || !filename.endsWith(".pc"))
    {
        return AnalysisReturn.NextHandler;
    }

    return AnalysisReturn.NextFunction;
}

/**
 * Do something with the pkgconfig file, for now we only
 * add providers.
 */
public AnalysisReturn handlePkgconfigFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    auto providerName = fileInfo.path.baseName()[0 .. $ - 3];

    /* emul32 becomes pkgconfig32() */
    immutable emul32 = fileInfo.path.canFind("/lib32/");

    auto prov = Provider(providerName, emul32 ? ProviderType.Pkgconfig32Name
            : ProviderType.PkgconfigName);
    analyser.bucket(fileInfo).addProvider(prov);

    string[] cmd = [
        "/usr/bin/pkg-config", "--print-requires", "--print-requires-private",
        "--silence-errors", fileInfo.fullPath
    ];
    import std.process : execute;
    import std.string : split, splitLines;
    import std.algorithm : map;

    string[string] env;
    env["LC_ALL"] = "C";
    auto ret = execute(cmd, env);

    if (ret.status != 0)
    {
        error(format!"Failed to run pkg-config: %s"(ret.output));
        return AnalysisReturn.NextFunction;
    }

    auto deps = ret.output.splitLines().map!((l) => l.split[0]);
    foreach (d; deps)
    {
        auto dep = Dependency(d, DependencyType.PkgconfigName);
        analyser.bucket(fileInfo).addDependency(dep);
    }
    return AnalysisReturn.NextHandler;
}
