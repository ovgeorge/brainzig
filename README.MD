Symmetrical Command Set for BrainZig -- more complicated BrainFuck for synthetic life experiments. 


Pointer Movement
> - Move head0 to the right.
< - Move head0 to the left.
} - Move head1 to the right.
{ - Move head1 to the left.
Data Manipulation
+ - Increment the byte at head0.
- - Decrement the byte at head0.
* - Increment the byte at head1.
_ - Decrement the byte at head1.
Data Transfer and Arithmetic
. - Copy the byte from head0 to head1.
, - Copy the byte from head1 to head0.
& - Add the byte at head1 to the byte at head0 and store the result at head0.
% - Subtract the byte at head1 from the byte at head0 and store the result at head0.
: - Add the byte at head0 to the byte at head1 and store the result at head1.
; - Subtract the byte at head0 from the byte at head1 and store the result at head1.
Control Structures
[ - If the byte at head0 is 0, jump forward to the matching ].
] - If the byte at head0 is not 0, jump backward to the matching [.
( - If the byte at head1 is 0, jump forward to the matching ).
) - If the byte at head1 is not 0, jump backward to the matching (.


I compile it this way:

~/zig-linux-x86_64-0.14.0-dev.367+a57479afc/zig build

Example usage:

./zig-out/bin/brainflex "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>."


