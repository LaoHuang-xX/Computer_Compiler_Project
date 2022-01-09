addi $1, $0, 20
addi $2, $0, 0
addi $3, $0, 3
addi $4, $0, 0
loop:beq $2, $1, end
bne $3, $4, add
sub $4, $4, $3
addi $2, $2, 1
j loop
add:addi $4, $4, 1
addi $2, $2, 1
j loop
end:addi $9, $0, 1

