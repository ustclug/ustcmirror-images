// The definitions and documents basically refer to FreeBSD Manual Page for `sysexits`.
//
// https://man.freebsd.org/cgi/man.cgi?query=sysexits

/** The program runs successfully. */
export const EX_OK = 0;

/** The command was used incorrectly, e.g., with the wrong number of arguments, a bad flag, a bad syntax in a parameter, or whatever. */
export const EX_USAGE = 64;

/**
 * The input data was incorrect in some way.
 *
 * This should only be used for user's data and not system files.
 */
export const EX_DATAERR = 65;

/**
 * An input file (not a system file) did not exist or was not readable.
 *
 * This could also include errors like "No message" to a mailer (if it cared to catch it).
 */
export const EX_NOINPUT = 66;

/**
 * The user specified did not exist.
 *
 * This might be used for mail addresses or remote logins.
 */
export const EX_NOUSER = 67;

/**
 * The host specified did not exist.
 *
 * This is used in mail addresses or network requests.
 */
export const EX_NOHOST = 68;

/**
 * A service is unavailable.
 *
 * This can occur if a support program or file does not exist.
 *
 * This can also be used as a catchall message when something you wanted to do does not work, but you do not know why.
 */
export const EX_UNAVAILABLE = 69;

/**
 * An internal software error has been detected.
 *
 * This should be limited to non-operating system related errors as possible.
 */
export const EX_SOFTWARE = 70;

/**
 * An operating system error has been detected.
 *
 * This is intended to be used for such things as "cannot fork", "cannot create pipe", or the like.
 *
 * It includes things like getuid returning a user that does not exist in the passwd file.
 */
export const EX_OSERR = 71;

/** Some system file (e.g., `/etc/passwd`, `/var/run/utx.active`, etc.) does not exist, cannot be opened, or has some sort of error (e.g., syntax error). */
export const EX_OSFILE = 72;

/** A (user specified) output file cannot be created. */
export const EX_CANTCREAT = 73;

/** An error occurred while doing I/O on some file. */
export const EX_IOERR = 74;

/**
 * Temporary failure, indicating something that is not really an error.
 *
 * In sendmail, this means that a mailer (e.g.) could not create a connection, and the request should be reattempted later.
 */
export const EX_TEMPFAIL = 75;

/** The remote system returned something that was "not possible" during a protocol exchange. */
export const EX_PROTOCOL = 76;

/**
 * You did not have sufficient permission to perform the operation.
 *
 * This is not intended for file system problems, which should use {@link EX_NOINPUT} or {@link EX_CANTCREAT}, but rather for higher level permissions.
 */
export const EX_NOPERM = 77;

/** Something was found in an unconfigured or misconfigured state. */
export const EX_CONFIG = 78;
