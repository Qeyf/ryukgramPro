# Composer automation lifetime

`SCIInstagramComposerAutomation` is retained by the global active-operation slot.
The terminal method must copy its completion block before clearing that slot.
Clearing the slot first can deallocate the receiver while the method is still
executing and turns the subsequent `self.completion` getter into a use-after-free.

The Instagram 434 / iOS 27 crash presented as:

```
objc_msgSend
-[SCIInstagramComposerAutomation finishWithSuccess:code:description:]
```

Do not reorder the terminal cleanup sequence without preserving an
`objc_precise_lifetime` strong receiver and a copied callback.
