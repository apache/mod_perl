#define mpxs_Apache__Command_next(cmd) \
(++cmd, ((cmd && cmd->name) ? cmd : NULL))
