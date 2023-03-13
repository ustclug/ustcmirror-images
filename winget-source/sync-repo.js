import async from 'async'
import { rm } from 'fs/promises'

import {
    buildPathpartMap,
    buildURIList,
    extractDatabaseFromBundle,
    getLocalPath,
    makeTempDirectory,
    setupEnvironment,
    syncFile
} from './utilities.js'

const { parallelLimit, remote, sqlite3, winston } = setupEnvironment();

winston.info(`start syncing with ${remote}`);

syncFile('source.msix').then(async updated => {
    if (!updated) {
        winston.info('nothing to update');
        return;
    }

    const temp = await makeTempDirectory('winget-repo-');
    const database = await extractDatabaseFromBundle(getLocalPath('source.msix'), temp);
    const db = new sqlite3.Database(database, sqlite3.OPEN_READONLY, (error) => {
        if (error) {
            winston.error(error);
            process.exit(74);
        }
    });

    db.all('SELECT * FROM pathparts', (error, rows) => {
        const pathparts = buildPathpartMap(error, rows);
        db.all('SELECT pathpart FROM manifest ORDER BY rowid DESC', (error, rows) => {
            db.close();
            const uris = buildURIList(error, rows, pathparts);
            async.eachLimit(uris, parallelLimit, syncFile, (error) => {
                rm(temp, { recursive: true });
                if (error) {
                    winston.error(error);
                    process.exit(69);
                }
                winston.info(`successfully synced with ${remote}`);
            });
        });
    });
});
