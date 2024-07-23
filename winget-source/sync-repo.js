import assert from 'assert'
import async from 'async'

import { rm } from 'fs/promises'
import { AsyncDatabase } from 'promised-sqlite3'
import { EX_IOERR, EX_OK, EX_SOFTWARE, EX_TEMPFAIL, EX_UNAVAILABLE } from './sysexits.js'

import {
    buildPathpartMap,
    buildURIList,
    exitWithCode,
    extractDatabaseFromBundle,
    getLocalPath,
    makeTempDirectory,
    saveFile,
    setupEnvironment,
    syncFile
} from './utilities.js'


const sourceV1Filename = 'source.msix';
const sourceV2Filename = 'source2.msix';

// set up configs and temp directory
const { parallelLimit, remote, sqlite3, winston } = setupEnvironment();
const tempDirectory = await makeTempDirectory('winget-repo-');

winston.info(`start syncing with ${remote}`);

try {
    // download V1 index package to buffer
    const [indexBuffer, modifiedDate, updated] = await syncFile(sourceV1Filename, true, false);
    if (!updated) {
        winston.info(`nothing to sync from ${remote}`);
        exitWithCode(EX_OK);
    }
    assert(indexBuffer !== null, "Failed to get the source index buffer!");

    // unpack, extract and load index database
    try {
        const databaseFilePath = await extractDatabaseFromBundle(indexBuffer, tempDirectory);
        const rawDatabase = new sqlite3.Database(databaseFilePath, sqlite3.OPEN_READONLY);

        // read manifest URIs from index database
        try {
            const db = new AsyncDatabase(rawDatabase)
            const pathparts = buildPathpartMap(await db.all('SELECT * FROM pathparts'));
            const uris = buildURIList(await db.all('SELECT pathpart FROM manifest ORDER BY rowid DESC'), pathparts);
            await db.close()

            // sync latest manifests in parallel
            try {
                await async.eachLimit(uris, parallelLimit, async (uri) => await syncFile(uri, false));
            } catch (error) {
                exitWithCode(EX_TEMPFAIL, error);
            }
        } catch (error) {
            exitWithCode(EX_SOFTWARE, error);
        }
    } catch (error) {
        exitWithCode(EX_IOERR, error);
    }

    // update index packages
    await saveFile(getLocalPath(sourceV1Filename), indexBuffer, modifiedDate);
    await syncFile(sourceV2Filename, true);
} catch (error) {
    exitWithCode(EX_UNAVAILABLE, error);
}

winston.info(`successfully synced with ${remote}`);

// clean up temp directory
await rm(tempDirectory, { recursive: true });
