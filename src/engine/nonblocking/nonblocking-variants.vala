/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2018 Michael Gratton <mike@vee.net>.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A broadcasting, manually-resetting asynchronous lock.
 *
 * This lock type will notify all waiting asynchronous tasks when
 * marked as being safe to pass, and requires a call to {@link
 * Lock.reset} to be marked as unsafe again.
 *
 * This class is ''not'' thread safe and should only be used by
 * asynchronous tasks.
 *
 * @see Lock
 */
public class GriabuntuMail.Nonblocking.Semaphore : GriabuntuMail.Nonblocking.Lock {

    /**
     * Constructs a new semaphore lock.
     *
     * The new lock is initially not able to be passed.
     */
    public Semaphore(Cancellable? cancellable = null) {
        base (true, false, cancellable);
    }

}

/**
 * A broadcasting, automatically-resetting asynchronous lock.
 *
 * This lock type will notify all waiting asynchronous tasks when
 * marked as being safe to pass, and will automatically reset as being
 * unsafe to pass after doing so.
 *
 * This class is ''not'' thread safe and should only be used by
 * asynchronous tasks.
 *
 * @see Lock
 */
public class GriabuntuMail.Nonblocking.Event : GriabuntuMail.Nonblocking.Lock {

    /**
     * Constructs a new event lock.
     *
     * The new lock is initially not able to be passed.
     */
    public Event(Cancellable? cancellable = null) {
        base (true, true, cancellable);
    }

}

/**
 * A single-task-notifying, automatically-resetting asynchronous lock.
 *
 * This lock type will the first asynchronous task waiting when marked
 * as being safe to pass, and will automatically reset as being unsafe
 * to pass after doing so.
 *
 * This class is ''not'' thread safe and should only be used by
 * asynchronous tasks.
 *
 * @see Lock
 */
public class GriabuntuMail.Nonblocking.Spinlock : GriabuntuMail.Nonblocking.Lock {

    /**
     * Constructs a new spin lock.
     *
     * The new lock is initially not able to be passed.
     */
    public Spinlock(Cancellable? cancellable = null) {
        base (false, true, cancellable);
    }

}
