import assert from 'assert'
import async from 'async'
import { writeFileSync } from 'fs'
import { rm } from 'fs/promises'
import { EX_IOERR, EX_TEMPFAIL, EX_UNAVAILABLE } from './sysexits.js'

import {
    buildPathpartMap,
    buildURIList,
    exitOnError,
    extractDatabaseFromBundle,
    getLocalPath,
    makeTempDirectory,
    setupEnvironment,
    syncFile
} from './utilities.js'

const { parallelLimit, remote, sqlite3, winston } = setupEnvironment();

winston.info(`start syncing with ${remote}`);

const sourceFilename = 'source.msix';

syncFile(sourceFilename, true, false).catch(exitOnError(EX_UNAVAILABLE)).then(async result => {
    assert(result, "Failed to catch error when syncing source index!");
    const [buffer, synced] = result;
    if (synced) {
        assert(buffer !== null, "Failed to get the source index buffer!");
        const temp = await makeTempDirectory('winget-repo-');
        const database = await extractDatabaseFromBundle(buffer, temp);
        const db = new sqlite3.Database(database, sqlite3.OPEN_READONLY, exitOnError(EX_IOERR));

        db.all('SELECT * FROM pathparts', (error, rows) => {
            const pathparts = buildPathpartMap(error, rows);
            db.all('SELECT pathpart FROM manifest ORDER BY rowid DESC', (error, rows) => {
                db.close();
                const uris = buildURIList(error, rows, pathparts);
                const download = async (uri) => await syncFile(uri, false);
                async.eachLimit(uris, parallelLimit, download, (error) => {
                    rm(temp, { recursive: true });
                    exitOnError(EX_TEMPFAIL)(error);
                    writeFileSync(getLocalPath(sourceFilename), buffer);
                    winston.info(`successfully synced with ${remote}`);
                });
            });
        });
    }
});
