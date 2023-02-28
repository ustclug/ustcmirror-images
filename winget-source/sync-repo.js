import async from 'async'
import sqlite3 from 'sqlite3'

import {
    buildPathpartMap,
    buildUriList,
    checkEnvironmentVariables,
    exatractDBFromBundle,
    getLocalPath,
    makeTempDirectory,
    syncFile
} from './utilities.js'

const { parallelLimit } = checkEnvironmentVariables();

syncFile('source.msix').then(async _ => {
    const temp = await makeTempDirectory('winget-repo-');
    const database = await exatractDBFromBundle(getLocalPath('source.msix'), temp);
    const db = new sqlite3.Database(database, sqlite3.OPEN_READONLY);

    db.all('SELECT * FROM pathparts', (error, rows) => {
        const pathparts = buildPathpartMap(error, rows);
        db.all('SELECT pathpart FROM manifest', (error, rows) => {
            db.close();
            const uris = buildUriList(error, rows, pathparts);
            const tasks = uris.map(uri => async () => { await syncFile(uri); return; });
            async.parallelLimit(tasks, parallelLimit);
        });
    });
});
