Focused declared-layout contract repair

The compiler implementation was already correct. The validator now follows its actual module, consumer and source manifest. Current C#/Native controls pass 8/8; actual validator assertions pass 27/27 including six rejected mutations. Full static collection decreases from 45 to 43 failures with no new failure. Remaining compiler gates are pending. Scratch references identify preserved original execution records.
