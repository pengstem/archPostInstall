# NeoMutt Quick Keys (this config)

This README documents the custom keys defined in this config.
For all other keys, press `?` inside NeoMutt to see the current menu help.

Reload config:
- `:source ~/.config/neomutt/neomuttrc`

---

## Sidebar

Toggle / open:
- `B`           Toggle sidebar visibility
- `Ctrl-o`      Open selected sidebar mailbox
- `go`          Open selected sidebar mailbox (vim-style)

Move selection:
- `Ctrl-n`      Next mailbox
- `Ctrl-p`      Previous mailbox
- `gj`          Next mailbox (vim-style)
- `gk`          Previous mailbox (vim-style)

Paging in sidebar list:
- `F3`          Page up
- `F4`          Page down
- `F5`          Previous mailbox with new mail
- `F6`          Next mailbox with new mail

---

## Index (message list)

Vim-style navigation:
- `gg`          First message
- `G`           Last message
- `h`           Previous page
- `l`           Next page
- `Ctrl-u`      Half page up
- `Ctrl-d`      Half page down

Threads:
- `za`          Toggle collapse current thread
- `zA`          Toggle collapse all threads

Search:
- `N`           Search opposite direction

Reply:
- `R`           Group reply (reply-all)

Flags / limits / save:
- `,a`          Toggle flagged, then move down
- `,u`          Limit to unread
- `,U`          Clear limit
- `,s`          Save message to Starred

---

## Pager (message view)

Vim-style navigation:
- `j`           Next line
- `k`           Previous line
- `h`           Previous page
- `l`           Next page
- `Ctrl-u`      Half page up
- `Ctrl-d`      Half page down

Search:
- `N`           Search opposite direction

---

## Gmail folder jumps (index)

Quick jumps:
- `gi`          INBOX
- `ga`          All Mail
- `gs`          Sent Mail
- `gd`          Drafts
- `gt`          Trash
- `g*`          Starred

Notes:
- `g` is bound to `noop` in both index and pager to allow multi-key `g...` bindings.

---

## Compose / send mail

Start composing (index/pager):
- `m`           New message
- `r`           Reply to sender
- `R`           Reply-all (custom binding in this config)
- `f`           Forward message

Compose menu (after editor returns):
- `t`           Edit To
- `c`           Edit Cc
- `b`           Edit Bcc
- `s`           Edit Subject
- `a`           Attach file
- `e`           Edit message body again
- `y`           Send message
- `P`           Postpone (save as draft)
- `q`           Abort/quit compose
- `?`           Help (shows active keys)

Notes:
- The message body opens in `$editor` (here: `nvim`); save/quit to return.
