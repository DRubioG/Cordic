
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;

entity TB_CORDIC is
end TB_CORDIC;

architecture Simulation of TB_CORDIC is

  constant G_WIDTH : integer := 16;
  constant G_ITER  : integer := 16;

  constant CLK_PERIOD : time := 20 ns;

  -- Escalas de coma fija
  constant C_SCALE_XY : real := 32768.0;
  
  constant C_SCALE_Z  : real := 8192.0;

  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal start : std_logic := '0';

  signal MODE : std_logic_vector(1 downto 0) := "00";
  signal OP   : std_logic                    := '0';

  -- Entradas STD_LOGIC_VECTOR
  signal x_in : std_logic_vector(G_WIDTH - 1 downto 0)
  := (others => '0');

  signal y_in : std_logic_vector(G_WIDTH - 1 downto 0)
  := (others => '0');

  signal z_in : std_logic_vector(G_WIDTH - 1 downto 0)
  := (others => '0');

  -- Salidas STD_LOGIC_VECTOR
  signal x_out : std_logic_vector(G_WIDTH - 1 downto 0);

  signal y_out : std_logic_vector(G_WIDTH - 1 downto 0);

  signal z_out : std_logic_vector(G_WIDTH - 1 downto 0);

  signal done : std_logic;

  -- Resultados
  signal operation : integer range 0 to 6 := 0;

  signal result_x : real := 0.0;
  signal result_y : real := 0.0;
  signal result_z : real := 0.0;

  signal sample_valid : std_logic := '0';

begin

  -- Reloj de 50 MHz
  clk <= not clk after 10 ns;

  -- Instancia del CORDIC
  CORDIC_inst : entity work.CORDIC
    generic map(
      G_WIDTH => G_WIDTH,
      G_ITER  => G_ITER
    )
    port map
    (
      CLK_I   => clk,
      RST_N_I => rst,
      START_I => start,
      MODE_I  => MODE,
      OP_I    => OP,
      X_I     => x_in,
      Y_I     => y_in,
      Z_I     => z_in,
      X_O     => x_out,
      Y_O     => y_out,
      Z_O     => z_out,
      DONE_O  => done
    );
  ------------------------------------------------
  -- PROCESO PRINCIPAL
  ------------------------------------------------

  process

    variable a, b  : real;
    variable angle : real;

    variable vx, vy, vz : real;

    variable ref_x, ref_y, ref_z : real;

    variable error_x, error_y, error_z : real;

    variable fixed_value : integer;
    ------------------------------------------------
    -- PROCEDIMIENTO DE EJECUCION
    ------------------------------------------------

    procedure execute_operation is
    begin

      wait until falling_edge(clk);
      start <= '1';

      wait until falling_edge(clk);
      start <= '0';

      wait until done = '1';

      wait for 1 ns;

      -- STD_LOGIC_VECTOR a SIGNED
      -- y conversion a REAL

      vx := real(to_integer(signed(x_out)))
        / C_SCALE_XY;

        -- vx := vx * 0.607252935;

      vy := real(to_integer(signed(y_out)))
        / C_SCALE_XY;

      vz := real(to_integer(signed(z_out)))
        / 32768.0;

      -- Errores absolutos

      error_x := abs(vx - ref_x);
      error_y := abs(vy - ref_y);
      error_z := abs(vz - ref_z);

      result_x <= vx;
      result_y <= vy;
      result_z <= vz;

      sample_valid <= '1';

      wait until falling_edge(clk);

      sample_valid <= '0';

      wait for 20 ns;

    end procedure;
  begin

    ------------------------------------------------
    -- RESET
    ------------------------------------------------

    rst   <= '0';
    start <= '0';

    wait for 100 ns;

    rst <= '1';

    wait until rising_edge(clk);
    ------------------------------------------------
    -- 1. ROTACION CIRCULAR
    ------------------------------------------------

    operation <= 1;

    MODE <= "00";
    OP   <= '0';

    angle := MATH_PI/6.0;

    x_in <= std_logic_vector(
      to_signed(19898, G_WIDTH));

    y_in <= std_logic_vector(
      to_signed(0, G_WIDTH));

    fixed_value := integer(angle * C_SCALE_Z);

    z_in <= std_logic_vector(
      to_signed(fixed_value, G_WIDTH));

    ref_x := cos(angle);
    ref_y := sin(angle);
    ref_z := 0.0;

    execute_operation;

    report "================================";
    report "OPERACION 1: ROTACION CIRCULAR";
    report "COSENO FPGA: " & real'image(vx);
    report "COSENO REAL: " & real'image(ref_x);
    report "SENO FPGA: " & real'image(vy);
    report "SENO REAL: " & real'image(ref_y);
    report "ERROR X: " & real'image(error_x);
    report "ERROR Y: " & real'image(error_y);
    ------------------------------------------------
    -- 2. VECTORIZACION CIRCULAR
    ------------------------------------------------

    operation <= 2;

    MODE <= "00";
    OP   <= '1';

    a := 0.5;
    b := 0.5;

    x_in <= std_logic_vector(
      to_signed(integer(a * C_SCALE_XY), G_WIDTH));

    y_in <= std_logic_vector(
      to_signed(integer(b * C_SCALE_XY), G_WIDTH));

    z_in <= (others => '0');

    ref_x := sqrt(a * a + b * b);
    ref_y := 0.0;
    ref_z := arctan(b/a);

    execute_operation;

    report "================================";
    report "OPERACION 2: VECTORIZACION CIRCULAR";
    report "MODULO FPGA: " & real'image(vx);
    report "MODULO REAL: " & real'image(ref_x);
    report "ANGULO FPGA: " & real'image(vz);
    report "ANGULO REAL: " & real'image(ref_z);
    report "ERROR MODULO: " & real'image(error_x);
    report "ERROR ANGULO: " & real'image(error_z);
    ------------------------------------------------
    -- 3. MULTIPLICACION LINEAL
    ------------------------------------------------

    operation <= 3;

    MODE <= "01";
    OP   <= '0';

    a := 0.5;
    b := 0.25;

    x_in <= std_logic_vector(
      to_signed(integer(a * C_SCALE_XY), G_WIDTH));

    y_in <= std_logic_vector(
      to_signed(0, G_WIDTH));

    z_in <= std_logic_vector(
      to_signed(integer(b * C_SCALE_XY), G_WIDTH));

    ref_x := a;
    ref_y := a * b;
    ref_z := 0.0;

    execute_operation;

    report "================================";
    report "OPERACION 3: MULTIPLICACION";
    report "A: " & real'image(a);
    report "B: " & real'image(b);
    report "RESULTADO FPGA: " & real'image(vy);
    report "RESULTADO REAL: " & real'image(ref_y);
    report "ERROR: " & real'image(error_y);
    ------------------------------------------------
    -- 4. DIVISION LINEAL
    ------------------------------------------------

    operation <= 4;

    MODE <= "01";
    OP   <= '1';

    a := 0.5;
    b := 0.25;

    x_in <= std_logic_vector(
      to_signed(integer(b * C_SCALE_XY), G_WIDTH));

    y_in <= std_logic_vector(
      to_signed(integer(a * C_SCALE_XY), G_WIDTH));

    z_in <= (others => '0');

    ref_x := b;
    ref_y := 0.0;
    ref_z := a/b;

    execute_operation;

    report "================================";
    report "OPERACION 4: DIVISION";
    report "DIVIDENDO: " & real'image(a);
    report "DIVISOR: " & real'image(b);
    report "COCIENTE FPGA: " & real'image(vz);
    report "COCIENTE REAL: " & real'image(ref_z);
    report "ERROR: " & real'image(error_z);
    ------------------------------------------------
    -- 5. ROTACION HIPERBOLICA
    ------------------------------------------------

    operation <= 5;

    MODE <= "10";
    OP   <= '0';

    angle := 0.5;

    x_in <= std_logic_vector(
      to_signed(27136, G_WIDTH));

    y_in <= std_logic_vector(
      to_signed(0, G_WIDTH));

    fixed_value := integer(angle * C_SCALE_Z);

    z_in <= std_logic_vector(
      to_signed(fixed_value, G_WIDTH));

    ref_x := (exp(angle) + exp(-angle))/2.0;
    ref_y := (exp(angle) - exp(-angle))/2.0;

    execute_operation;

    report "================================";
    report "OPERACION 5: ROTACION HIPERBOLICA";
    report "COSH FPGA: " & real'image(vx);
    report "COSH REAL: " & real'image(ref_x);
    report "SINH FPGA: " & real'image(vy);
    report "SINH REAL: " & real'image(ref_y);
    report "ERROR COSH: " & real'image(error_x);
    report "ERROR SINH: " & real'image(error_y);
    ------------------------------------------------
    -- 6. VECTORIZACION HIPERBOLICA
    ------------------------------------------------

    operation <= 6;

    MODE <= "10";
    OP   <= '1';

    a := 0.5;
    b := 0.25;

    x_in <= std_logic_vector(
      to_signed(integer(a * C_SCALE_XY), G_WIDTH));

    y_in <= std_logic_vector(
      to_signed(integer(b * C_SCALE_XY), G_WIDTH));

    z_in <= (others => '0');

    ref_x := sqrt(a * a - b * b);
    ref_y := 0.0;
    ref_z := 0.5 * log((a + b)/(a - b));

    execute_operation;

    report "================================";
    report "OPERACION 6: VECTORIZACION HIPERBOLICA";
    report "MODULO FPGA: " & real'image(vx);
    report "MODULO REAL: " & real'image(ref_x);
    report "ANGULO FPGA: " & real'image(vz);
    report "ANGULO REAL: " & real'image(ref_z);
    report "ERROR MODULO: " & real'image(error_x);
    report "ERROR ANGULO: " & real'image(error_z);
    ------------------------------------------------
    -- FIN
    ------------------------------------------------

    operation <= 0;

    report "================================";
    report "TODAS LAS OPERACIONES FINALIZADAS";

    wait;

  end process;

end Simulation;
