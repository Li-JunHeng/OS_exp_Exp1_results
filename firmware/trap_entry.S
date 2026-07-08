// The trap vector lives in start.S so the reset jump and .org 0x80 padding stay
// in one boot section. This file is intentionally kept as the firmware trap
// entry placeholder for future split-out assembly helpers.
