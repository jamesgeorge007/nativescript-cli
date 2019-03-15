import * as path from "path";
import { cache } from "../common/decorators";

export class TestInitializationService implements ITestInitializationService {
	private configsPath = path.join(__dirname, "..", "..", "config");

	constructor(private $fs: IFileSystem) { }

	@cache()
	public getDependencies(selectedFramework: string): IDependencyInformation[] {
		const dependenciesPath = path.join(this.configsPath, "test-dependencies.json");
		const allDependencies: { name: string, framework: string }[] = this.$fs.readJson(dependenciesPath);
		const targetFrameworkDependencies: IDependencyInformation[] = allDependencies
			.filter(dependency => !dependency.framework || dependency.framework === selectedFramework);

		return targetFrameworkDependencies;
	}

	@cache()
	public getDependenciesVersions(): IDictionary<string> {
		const dependenciesVersionsPath = path.join(this.configsPath, "test-deps-versions-generated.json");
		const dependenciesVersions = this.$fs.readJson(dependenciesVersionsPath);

		return dependenciesVersions;
	}
}

$injector.register("testInitializationService", TestInitializationService);
