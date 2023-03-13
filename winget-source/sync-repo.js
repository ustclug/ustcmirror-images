import async from 'async'
import { rm } from 'fs/promises'

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

syncFile('source.msix').catch(exitOnError(69)).then(async updated => {
    if (!updated) {
        winston.info('nothing to update');
        return;
    }

    const temp = await makeTempDirectory('winget-repo-');
    const database = await extractDatabaseFromBundle(getLocalPath('source.msix'), temp);
    const db = new sqlite3.Database(database, sqlite3.OPEN_READONLY, exitOnError(74));

    db.all('SELECT * FROM pathparts', (error, rows) => {
        const pathparts = buildPathpartMap(error, rows);
        db.all('SELECT pathpart FROM manifest ORDER BY rowid DESC', (error, rows) => {
            db.close();
            const uris = buildURIList(error, rows, pathparts);
            async.eachLimit(uris, parallelLimit, syncFile, (error) => {
                rm(temp, { recursive: true });
                exitOnError(75)(error);
                winston.info(`successfully synced with ${remote}`);
            });
        });
    });
});
