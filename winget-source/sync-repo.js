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
    setupWinstonLogger,
    syncFile
} from './utilities.js'

const { debugMode, logFile, parallelLimit, remote } = requireEnvironmentVariables();

const { Database } = debugMode ? sqlite3.verbose() : sqlite3;
const logger = setupWinstonLogger(debugMode, logFile);

logger.info(`start syncing with ${remote}`);

syncFile('source.msix').then(async updated => {
    if (!updated) {
        logger.info('nothing to update');
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
                    logger.error(error);
                    process.exit(-1);
                }
                logger.info(`successfully synced with ${remote}`);
            });
        });
    });
});
