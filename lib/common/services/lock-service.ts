import * as lockfile from "proper-lockfile";
import * as path from "path";
import { cache } from "../decorators";
import { getHash } from "../helpers";

export class LockService implements ILockService {
	private currentlyLockedFiles: string[] = [];

	@cache()
	private get defaultLockFilePath(): string {
		return this.getAbsoluteLockFilePath("lockfile.lock");
	}

	private getAbsoluteLockFilePath(relativeLockFilePath: string) {
		return path.join(this.$settingsService.getProfileDir(), relativeLockFilePath);
	}

	private get defaultLockParams(): ILockOptions {
		const lockParams: ILockOptions = {
			// https://www.npmjs.com/package/retry#retrytimeoutsoptions
			retriesObj: { retries: 13, minTimeout: 100, maxTimeout: 1000, factor: 2 },
			stale: 10 * 1000,
			realpath: false
		};

		return lockParams;
	}

	constructor(private $fs: IFileSystem,
		private $settingsService: ISettingsService,
		private $processService: IProcessService) {
		this.$processService.attachToProcessExitSignals(this, () => {
			const locksToRemove = _.clone(this.currentlyLockedFiles);
			for (const lockToRemove of locksToRemove) {
				lockfile.unlockSync(lockToRemove);
				this.cleanLock(lockToRemove);
			}
		});
	}

	public async executeActionWithLock<T>(action: () => Promise<T>, lockFilePath?: string, lockOpts?: ILockOptions): Promise<T> {
		const releaseFunc = await this.lock(lockFilePath, lockOpts);

		try {
			const result = await action();
			return result;
		} finally {
			releaseFunc();
		}
	}

	public async lock(lockFilePath?: string, lockOpts?: ILockOptions): Promise<() => void> {
		const { filePath, fileOpts } = this.getLockFileSettings(lockFilePath, lockOpts);
		this.currentlyLockedFiles.push(filePath);
		this.$fs.writeFile(filePath, "");

		try {
			const releaseFunc = await lockfile.lock(filePath, fileOpts);
			return async () => {
				await releaseFunc();
				this.cleanLock(filePath);
			};
		} catch (err) {
			throw new Error(`Timeout while waiting for lock "${filePath}"`);
		}
	}

	public unlock(lockFilePath?: string): void {
		const { filePath } = this.getLockFileSettings(lockFilePath);
		lockfile.unlockSync(filePath);
		this.cleanLock(filePath);
	}

	private cleanLock(lockPath: string): void {
		_.remove(this.currentlyLockedFiles, e => e === lockPath);
		this.$fs.deleteFile(lockPath);
	}

	private getLockFileSettings(filePath?: string, fileOpts?: ILockOptions): { filePath: string, fileOpts: ILockOptions } {
		if (filePath && !path.isAbsolute(filePath)) {
			filePath = this.getAbsoluteLockFilePath(filePath);
		}

		filePath = filePath || this.defaultLockFilePath;
		fileOpts = fileOpts ? _.assign({}, this.defaultLockParams, fileOpts) : this.defaultLockParams;

		fileOpts.retriesObj = fileOpts.retriesObj || {};
		if (fileOpts.retries) {
			fileOpts.retriesObj.retries = fileOpts.retries;
		}

		if (fileOpts.retryWait) {
			// backwards compatibility
			fileOpts.retriesObj.minTimeout = fileOpts.retriesObj.maxTimeout = fileOpts.retryWait;
		}

		(<any>fileOpts.retries) = fileOpts.retriesObj;

		return {
			filePath: this.getShortFileLock(filePath),
			fileOpts
		};
	}

	private getShortFileLock(filePath: string) {
		const dirPath = path.dirname(filePath);
		const fileName = path.basename(filePath);
		const hashedFileName = getHash(fileName, { algorithm: "MD5" });
		filePath = path.join(dirPath, hashedFileName);
		return filePath;
	}
}

$injector.register("lockService", LockService);
// backwards compatibility
$injector.register("lockfile", LockService);
