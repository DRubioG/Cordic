nvc -a  cordic.vhd 
nvc -a cordic_tb.vhd 

nvc -e TB_CORDIC

nvc -r TB_CORDIC --wave=TB_CORDIC.vcd --stop-time=20us --dump-arrays