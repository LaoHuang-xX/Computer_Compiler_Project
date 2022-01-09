vlib work

;# Compile components if any
vcom instruction_memory.vhd
vcom 2_bit_predictor_IF_datapath.vhd
vcom ID_datapath.vhd
vcom EX_datapath.vhd
vcom MEM_datapath.vhd
vcom WB_datapath.vhd
vcom mips_pipeline.vhd

;# Start simulation
vsim work.mips_pipeline

;# Run for 20,000 ns
run 20000ns
