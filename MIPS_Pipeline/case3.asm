addi $1, $0, 5
addi $2, $0, 0
addi $3, $0, 1
addi $4, $0, 0
loop:beq $2, $1, end
beq $3, $4, sub
add $4, $4, $3
addi $2, $2, 1
j loop
sub: sub $4, $4, $3
addi $2, $2, 1
j loop
end:addi $9, $0, 1