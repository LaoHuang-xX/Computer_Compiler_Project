addi $1, $0, 5
addi $2, $0, 0
loop:beq $2, $1, end
l1:beq $0, $0, l2
l2:addi $2, $2, 1
j loop
end:addi $9, $0, 1