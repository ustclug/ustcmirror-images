import async from 'async'
import sqlite3 from 'sqlite3'
import { rm } from 'fs/promises'

import {
    buildPathpartMap,
    buildURIList,
    extractDatabaseFromBundle,
    getLocalPath,
    makeTempDirectory,
    requireEnvironmentVariables,
    syncFile
} from './utilities.js'

const { debugMode, parallelLimit } = requireEnvironmentVariables();
const { Database } = debugMode ? sqlite3.verbose() : sqlite3;

syncFile('source.msix').then(async updated => {
    if (!updated) {
        console.info('nothing to update');
        return;
    }

    const temp = await makeTempDirectory('winget-repo-');
    const database = await extractDatabaseFromBundle(getLocalPath('source.msix'), temp);
    const db = new Database(database, sqlite3.OPEN_READONLY);

    db.all('SELECT * FROM pathparts', (error, rows) => {
        const pathparts = buildPathpartMap(error, rows);
        db.all('SELECT pathpart FROM manifest', (error, rows) => {
            db.close();
            const uris = buildURIList(error, rows, pathparts);
            async.eachLimit(uris, parallelLimit, syncFile, (error) => {
                rm(temp, { recursive: true });
                if (error) {
                    console.error(error);
                    process.exit(-1);
                }
            });
        });
    });
});
