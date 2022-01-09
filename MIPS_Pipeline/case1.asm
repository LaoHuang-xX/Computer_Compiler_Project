addi $1, $0, 5
addi $2, $0, 0
loop:beq $2, $1, end
addi $3, $3, 1
addi $2, $2, 1
j loop
end:addi $9, $0, 1