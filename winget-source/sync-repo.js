import assert from 'assert'
import async from 'async'

import { rm } from 'fs/promises'
import { EX_IOERR, EX_TEMPFAIL, EX_UNAVAILABLE } from './sysexits.js'

import {
    buildPathpartMap,
    buildURIList,
    exitOnError,
    extractDatabaseFromBundle,
    getLocalPath,
    makeTempDirectory,
    saveFile,
    setupEnvironment,
    syncFile
} from './utilities.js'


const { parallelLimit, remote, sqlite3, winston } = setupEnvironment();

winston.info(`start syncing with ${remote}`);

const sourceV1Filename = 'source.msix';
const sourceV2Filename = 'source2.msix';

syncFile(sourceV1Filename, true, false).catch(exitOnError(EX_UNAVAILABLE)).then(async result => {
    assert(result, "Failed to catch error when syncing source index!");
    const [indexBuffer, modifiedDate, synced] = result;
    if (synced) {
        assert(indexBuffer !== null, "Failed to get the source index buffer!");
        const temp = await makeTempDirectory('winget-repo-');
        const database = await extractDatabaseFromBundle(indexBuffer, temp);
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
                    saveFile(getLocalPath(sourceV1Filename), indexBuffer, modifiedDate).then(_ =>
                        syncFile(sourceV2Filename, true)
                    ).then(_ => {
                        winston.info(`successfully synced with ${remote}`);
                    });
                });
            });
        });
    }
});
