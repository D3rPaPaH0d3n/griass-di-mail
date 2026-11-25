/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A primitive for creating critical sections inside of asynchronous tasks.
 *
 * Two methods can be used for executing code protected by this
 * mutex. The easiest is to create a {@link CriticalSection} delegate
 * and pass it to {@link execute_locked}. This will manage acquiring
 * the lock as needed. The lower-level method is to call {@link
 * claim_async}, execute the critical section, then ensure {@link
 * release} is always called afterwards.
 *
 * This class is ''not'' thread safe and should only be used by
 * asynchronous tasks.
 */
public class GriabuntuMail.Nonblocking.Mutex : BaseObject {

    public const int INVALID_TOKEN = -1;

    /** A delegate that can be executed by this lock. */
    public delegate void CriticalSection() throws GLib.Error;

    private Spinlock spinlock = new Spinlock();
    private bool locked = false;
    private int next_token = INVALID_TOKEN + 1;
    private int locked_token = INVALID_TOKEN;


    /**
     * Returns true if the {@link Mutex} has been claimed by a task.
     */
    public bool is_locked() {
        return locked;
    }

    /**
     * Executes a critical section while protected by this mutex.
     *
     * This high-level method takes care of claiming, executing, then
     * releasing the mutex, without requiring the caller to manage any
     * this.
     *
     * @throws GLib.IOError.CANCELLED thrown if the caller's
     * cancellable is cancelled before execution is completed
     * @throws GLib.Error if an error occurred during execution of
     * //target//.
     */
    public async void execute_locked(Mutex.CriticalSection target,
                                     Cancellable? cancellable = null)
        throws Error {
        int token = yield claim_async(cancellable);
        try {
            target();
        } finally {
            try {
                release(ref token);
            } catch (Error err) {
                debug("Mutex error releasing token: %s", err.message);
            }
        }
    }

    /**
     * Locks the mutex for execution inside a critical section.
     *
     * If already claimed, this call will block asynchronously waiting
     * for the mutex to be released.
     *
     * @return A token which must be passed to {@link release} when
     * the critical section has completed executing.
     */
    // The cancellable is typed as Object so Vala doesn't attach it to
    // this method's GTask, which would discard a claimed token if
    // cancelled before the caller resumes
    public async int claim_async(GLib.Object? cancellable = null) throws Error {
        var wait_cancellable = cancellable as Cancellable;
        for (;;) {
            if (!locked) {
                locked = true;
                do {
                    locked_token = next_token++;
                } while (locked_token == INVALID_TOKEN);

                return locked_token;
            }

            try {
                yield spinlock.wait_async(wait_cancellable);
            } catch (GLib.Error err) {
                if (!locked) {
                    spinlock.blind_notify();
                }
                throw err;
            }
        }
    }

    /**
     * Releases the lock at the end of executing a critical section.
     *
     * The token returned by {@link claim_async} must be supplied as a
     * parameter.  It will be modified by this call so it can't be
     * reused.
     *
     * Throws IOError.INVALID_ARGUMENT if the token was not the one
     * returned by claim_async.
     */
    public void release(ref int token) throws Error {
        if (token != locked_token || token == INVALID_TOKEN)
            throw new IOError.INVALID_ARGUMENT("Token %d is not the lock token", token);

        locked = false;
        token = INVALID_TOKEN;
        locked_token = INVALID_TOKEN;

        spinlock.notify();
    }

}
