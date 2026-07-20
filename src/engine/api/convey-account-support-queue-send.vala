/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * An account that supports staged outbox sending with undo.
 *
 * Accounts that implement this interface allow a composed email to be
 * saved into the outbox folder first ({@link save_email}), giving the
 * user a window to cancel the send, before it is finally committed for
 * delivery ({@link queue_email}).  A staged message can be discarded at
 * any point before delivery via {@link discard_staged_email}.
 *
 * The token returned by {@link save_email} is an opaque string that
 * uniquely identifies the staged message on the server.  It must be
 * passed unchanged to {@link queue_email} or
 * {@link discard_staged_email}.
 */
public interface Convey.AccountSupport.QueueSend : Convey.Account {

    /**
     * Emitted after an email has been successfully delivered.
     *
     * Listeners can use this to show notifications, play sounds, etc.
     */
    public signal void email_sent();


    /**
     * Stages a composed email in the account's outbox without sending it.
     *
     * The message is stored server-side in the outbox folder.  The
     * returned token must be passed to {@link queue_email} to deliver
     * it, or to {@link discard_staged_email} to cancel the send.
     */
    public abstract async string save_email(
        Convey.ComposedEmail composed,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error;

    /**
     * Delivers a message previously staged by {@link save_email}.
     *
     * The server sends the message and moves it to Sent Items.
     * The token is consumed and must not be used again after this call.
     */
    public abstract async void queue_email(
        string token,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error;

    /**
     * Discards a message previously staged by {@link save_email}.
     *
     * Removes the staged message from the outbox without sending it,
     * implementing the "undo send" action.
     * The token is consumed and must not be used again after this call.
     */
    public abstract async void discard_staged_email(
        string token,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error;

}
