--! | Configuración | Rotación | Vectorización |
--! |---------------|----------|---------------|
--! | Lineal | Op Y = X*Y | Op Z = X/Y |
--! | Hiperbólica | Op X = CosH(X)/ OpY = SinH(X) | Op Z = ArcTanH |
--! | Circular | Op X = Cos(X) / Op Y = Sin(Y) | Op Z = ArcTanH(Y) / Op X = SQRT(X^2 + Y^2) |

--! Fórmulas
--! --
--! X_i+1 = X_i - m·d_i·Y_i·2^i
--!
--! Y_i+1 = Y_i + X_i·d_i·2^i
--!
--! Z_i+1 = Z_i - d_i·e_i

--!  m
--! --
--!  | valor | Parámetro |
--!  |------|---------|
--!  |  1  | Circular |
--!  |  0  | Linear |
--!  |  -1  | Hiperbolico |

--! e_i
--! --
--! | Configuración | e_i |
--! |---------------|-----|
--! | Lineal | 2^-i |
--! | Hiperbólico | ArcTanH(2^-i) |
--! | Circular | ArcTan(2^-i) |

--! Modo de operación (MODE_I) -> m
--! --
--! | Modo | Configuración |
--! |------|---------|
--! |  00  | Circular |
--! |  01  | Linear |
--! |  10  | Hiperbolico |

--! Operación del Cordic (OP_I) -> e_i
--! --
--! | Valor | Operación |
--! |-------|-----------|
--! |   0   | Rotación |
--! |   1   | Vectorización |
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;

entity CORDIC is
  generic (
    --! Ancho de los datos de entrada.
    G_WIDTH : integer := 16;
    --! Número de iteraciones.
    G_ITER : integer := 16
  );
  port (
    --! Reloj de entrada del módulo.
    CLK_I : in std_logic;
    --! Reset de entrada del módulo. Activo a nivel bajo.
    RST_N_I : in std_logic;
    --! Señal de arranque del módulo. Activo a nivel alto.
    START_I : in std_logic;
    --! Modo de operación.
    --! | Modo | Configuración |
    --! |------|---------|
    --! |  00  | Circular |
    --! |  01  | Linear |
    --! |  10  | Hiperbolico |
    MODE_I : in std_logic_vector(1 downto 0);
    --! Operación del Cordic.
    --! | Valor | Operación |
    --! |-------|-----------|
    --! |   0   | Rotación |
    --! |   1   | Vectorización |
    OP_I : in std_logic;
    --! Entrada X del módulo.
    X_I : in std_logic_vector(G_WIDTH - 1 downto 0);
    --! Entrada Y del módulo.
    Y_I : in std_logic_vector(G_WIDTH - 1 downto 0);
    --! Entrada Z del módulo.
    Z_I : in std_logic_vector(G_WIDTH - 1 downto 0);
    --! Salida X del módulo.
    X_O : out std_logic_vector(G_WIDTH - 1 downto 0);
    --! Salida Y del módulo.
    Y_O : out std_logic_vector(G_WIDTH - 1 downto 0);
    --! Salida Z del módulo.
    Z_O : out std_logic_vector(G_WIDTH - 1 downto 0);
    --! Indicador de finalización del CORDIC.
    DONE_O : out std_logic
  );
end CORDIC;

architecture Behavioral of CORDIC is
  -----------------------------------------------
  -- Generación de las tablas de constantes.
  -----------------------------------------------

  -- ARCOTANGENTE
  --! Type para la tabla del arcotangente.
  type t_atan_array is array (0 to G_ITER - 1) of signed(G_WIDTH - 1 downto 0);

  --! Función para calcular el valor del arcotangente.
  function f_calculate_atan_table(num_iter : integer) return t_atan_array is
    -- Tabla circular: atan(2^-i), Q3.13
    variable v_angle     : real;
    variable v_value     : integer;
    variable v_table     : t_atan_array;
    constant C_FRAQ_ATAN : integer := 13;
  begin

    for i in 0 to num_iter - 1 loop
      v_angle    := arctan(2.0 ** (-i));
      v_value    := integer(v_angle * 2.0 ** C_FRAQ_ATAN);
      v_table(i) := to_signed(v_value, G_WIDTH);
    end loop;

    return v_table;
  end function;

  --! Tabla con el valor del arcotangente.
  constant C_ATAN_TABLE : t_atan_array := f_calculate_atan_table(G_ITER);

  -- ARCOTANGENTE HIPERBÓLICA
  --! Type para la tabla del arcotangente hiperbólica.
  type t_atanh_array is array (0 to G_ITER) of signed(G_WIDTH - 1 downto 0);

  --! Función para calcular el valor del arcotangente hiperbólico.
  function f_calculate_atanh_table(num_iter : integer) return t_atanh_array is
    -- Tabla hiperbolica: atanh(2^-i), Q3.13
    variable v_x          : real;
    variable v_angle      : real;
    variable v_value      : integer;
    variable v_table      : t_atanh_array;
    constant C_FRAQ_ATANH : integer := 13;

  begin
    v_table(0) := (others => '0');
    for i in 1 to num_iter loop
      v_x     := 2.0 ** (-i);
      v_angle := 0.5 * log((1.0 + v_x) / (1.0 - v_x));
      -- Conversion a Q3.13
      v_value    := integer(v_angle * 2.0 ** C_FRAQ_ATANH);
      v_table(i) := to_signed(v_value, G_WIDTH);
    end loop;

    return v_table;
  end function;

  --! Tabla con el valor del arcotangente hiperbólico.
  constant C_ATANH_TABLE : t_atanh_array := f_calculate_atanh_table(G_ITER);

  -- HIPERBOLICO
  --! Type para la tabla con los valores hiperbólicos.
  type t_hyper_index is array (0 to G_ITER - 1) of integer;

  --! Función para calcular los valores hiperbólicos.
  function f_generate_hyperbolic_index(num_iter : integer) return t_hyper_index is
    variable table                                : t_hyper_index;
    variable idx                                  : integer := 1;
    variable repeat_idx                           : integer := 4;
  begin

    for n in 0 to num_iter - 1 loop
      table(n) := idx;
      if idx = repeat_idx then
        repeat_idx := 3 * repeat_idx + 1;
      else
        idx := idx + 1;
      end if;
    end loop;

    return table;
  end function;

  --! Tabla con los valores hiperbólicos.
  constant C_HYPER_INDEX : t_hyper_index := f_generate_hyperbolic_index(G_ITER);

  -----------------------------------------------
  -- Definción de señales
  -----------------------------------------------

  --! Definición de la máquina de estados.
  type fsm is (
    --! Estado de espera.
    SM_IDLE,
    --! Estado para calcular el Cordic
    SM_CALCULATE,
    --! Estado de finalización del Cordic.
    SM_FINISH
  );
  --! Registro con el valor actual del estado.
  signal re_state : fsm := SM_IDLE;

  -- Constante de entrada.
  --! Constante para el modo circular del Cordic.
  constant C_CIRCULAR : std_logic_vector(MODE_I'range) := "00";
  --! Constante para el modo lineal del Cordic.
  constant C_LINEAL : std_logic_vector(MODE_I'range) := "01";
  --! Constante para el modo hiperbólico del Cordic.
  constant C_HIPERBOLICO : std_logic_vector(MODE_I'range) := "10";
  --! Constante para la operación de rotación.
  constant C_ROTACION : std_logic := '0';
  --! Constante para la operación de vectorización.
  constant C_VECTORIZACION : std_logic := '1';

  --! Calculo del valor exponencial de la parte decimal de entrada del módulo.
  constant C_FRAC : integer := 2 ** (G_WIDTH - 1);

  --! Registro de la entrada X_I ampliado con dos bits más.
  signal r_x : signed(G_WIDTH + 1 downto 0);
  --! Registro de la entrada Y_I ampliado con dos bits más.
  signal r_y : signed(G_WIDTH + 1 downto 0);
  --! Registro de la entrada Z_I ampliado con dos bits más.
  signal r_z : signed(G_WIDTH + 1 downto 0);
  --! Registro para salvar el modo de operación de entrada.
  signal r_mode : std_logic_vector(MODE_I'range);
  --! Registro para salvar la operación de entrada.
  signal r_op : std_logic;

  --! Registro contador con el número de iteraciones.
  signal r_cont_iter : integer range 0 to G_ITER := 0;

begin

  -- assert G_WIDTH >= 16 report "WIDTH debe ser como minimo 16" severity failure;

  -- assert G_ITER >= 1 and G_ITER <= 16 report "ITER debe estar entre 1 y 16" severity failure;

  -- Salidas
  --! Asignación de la salida X.
  X_ASSIGN : X_O <= std_logic_vector(resize(r_x, G_WIDTH));
  --! Asignación de la salida Y.
  Y_ASSIGN : Y_O <= std_logic_vector(resize(r_y, G_WIDTH));
  --! Asignación de la salida Z.
  Z_ASSIGN : Z_O <= std_logic_vector(resize(r_z, G_WIDTH));

  --! Proceso de control de la máquina de estados.
  FSM_PROCESS : process (CLK_I)
  begin
    if rising_edge(CLK_I) then
      if RST_N_I = '0' then
        re_state <= SM_IDLE;
      else
        case re_state is
          when SM_IDLE =>
            re_state <= SM_IDLE;
            if START_I = '1' then
              re_state <= SM_CALCULATE;

            end if;
          when SM_CALCULATE =>
            re_state <= SM_CALCULATE;
            if r_cont_iter >= G_ITER - 1 then
              re_state <= SM_FINISH;
            end if;

          when SM_FINISH =>
            re_state <= SM_IDLE;

        end case;
      end if;
    end if;
  end process;

  --! Este process genera la señal de finalización del cálculo del CORDIC.
  DONE_OUTPUT : process (CLK_I)
  begin
    if rising_edge(CLK_I) then
      if RST_N_I = '0' then
        DONE_O <= '0';
      else
        DONE_O <= '0';
        if re_state = SM_FINISH then
          DONE_O <= '1';
        end if;
      end if;
    end if;
  end process;

  --! Este apartado calcula el valor CORDIC.
  CORDIC_CALULO : process (CLK_I)
    variable x_shift    : signed(G_WIDTH + 1 downto 0);
    variable y_shift    : signed(G_WIDTH + 1 downto 0);
    variable angle_temp : signed(G_WIDTH + 1 downto 0);
    variable step_temp  : signed(G_WIDTH + 1 downto 0);
    variable h_iter     : integer;
  begin
    if rising_edge(CLK_I) then
      if RST_N_I = '0' then
        r_x    <= (others => '0');
        r_y    <= (others => '0');
        r_z    <= (others => '0');
        r_mode <= "00";
        r_op   <= '0';

      else
        --! Durante este estado se guardan los valores de los puertos de entrada hasta que se inicia el Cordic.
        if re_state = SM_IDLE then
          -- Amplicación del tamaño del puerto de entrada para poder realizar operaciones posteriores.
          r_x <= resize(signed(X_I), G_WIDTH + 2);
          r_y <= resize(signed(Y_I), G_WIDTH + 2);
          r_z <= resize(signed(Z_I), G_WIDTH + 2);

          r_mode <= MODE_I;
          r_op   <= OP_I;

        elsif re_state = SM_CALCULATE then

          -- Desplazamiento del valor calculado dependiendo de la operación.
          x_shift := shift_right(r_x, r_cont_iter);
          y_shift := shift_right(r_y, r_cont_iter);

          --------------------------------
          -- MODO CIRCULAR (m=1)
          --------------------------------
          if r_mode = C_CIRCULAR then
            -- Rotación = X -> Cos / Y -> Sen
            -- Vectorización = Z -> ArcTan / X -> SQRT(X^2+Y^2)

            -- Recoger el valor actual del arcotangente y ampliar el tamaño 2 bits.
            angle_temp := resize(C_ATAN_TABLE(r_cont_iter), G_WIDTH + 2);

            if r_op = C_ROTACION then
              -- ROTACION
              if r_z >= 0 then -- Valor positivo.
                r_x <= r_x - y_shift;
                r_y <= r_y + x_shift;
                r_z <= r_z - angle_temp;
              else -- Valor negativo.
                r_x <= r_x + y_shift;
                r_y <= r_y - x_shift;
                r_z <= r_z + angle_temp;
              end if;

            elsif r_op = C_VECTORIZACION then
              -- VECTORIZACION
              if r_y >= 0 then -- Valor positivo.
                r_x <= r_x + y_shift;
                r_y <= r_y - x_shift;
                r_z <= r_z + angle_temp;
              else -- Valor negativo.
                r_x <= r_x - y_shift;
                r_y <= r_y + x_shift;
                r_z <= r_z - angle_temp;
              end if;
            end if;

            --------------------------------
            -- MODO LINEAL (m=0)
            --------------------------------
          elsif r_mode = C_LINEAL then
            -- Rotación = Multiplicacion lineal.
            -- Vectorización = División lineal.
            -- X permanece constante.
            -- Z utiliza Q1.15.

            -- División periodica con el valor de la iterción del valor de la fración del número.
            step_temp := shift_right(to_signed(C_FRAC, G_WIDTH + 2), r_cont_iter);

            if r_op = C_ROTACION then
              --------------------------------
              -- MULTIPLICACION
              --------------------------------
              if r_z >= 0 then -- Valor positivo.
                r_y <= r_y + x_shift;
                r_z <= r_z - step_temp;
              else -- Valor negativo.
                r_y <= r_y - x_shift;
                r_z <= r_z + step_temp;
              end if;

            elsif r_op = C_VECTORIZACION then
              --------------------------------
              -- DIVISION
              --------------------------------
              if r_y >= 0 then -- Valor positivo.
                r_y <= r_y - x_shift;
                r_z <= r_z + step_temp;
              else -- Valor negativo.
                r_y <= r_y + x_shift;
                r_z <= r_z - step_temp;
              end if;
            end if;

            --------------------------------
            -- MODO HIPERBOLICO (m=-1)
            --------------------------------
          elsif r_mode = C_HIPERBOLICO then
            -- Rotación = X -> CosH / Y -> SenH
            -- Vectorización = Z -> ArcTanH

            -- Recoger el valor de la tabla de vectorización.
            h_iter := C_HYPER_INDEX(r_cont_iter);

            -- División por el valor de la iteración.
            x_shift := shift_right(r_x, h_iter);
            y_shift := shift_right(r_y, h_iter);

            -- Recoger el valor del arcotagente de la tabla
            angle_temp := resize(C_ATANH_TABLE(r_cont_iter), G_WIDTH + 2);

            if r_op = C_ROTACION then
              -- ROTACION HIPERBOLICA
              if r_z >= 0 then -- Valor positivo.
                r_x <= r_x + y_shift;
                r_y <= r_y + x_shift;
                r_z <= r_z - angle_temp;
              else -- Valor negativo.
                r_x <= r_x - y_shift;
                r_y <= r_y - x_shift;
                r_z <= r_z + angle_temp;
              end if;

            elsif r_op = C_VECTORIZACION then
              -- VECTORIZACION HIPERBOLICA
              if r_y >= 0 then -- Valor positivo.
                r_x <= r_x - y_shift;
                r_y <= r_y - x_shift;
                r_z <= r_z + angle_temp;
              else -- Valor negativo.
                r_x <= r_x + y_shift;
                r_y <= r_y + x_shift;
                r_z <= r_z - angle_temp;

              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  --! Este process cuenta el número de iteración que lleva la operación del Cordic.
  CONTADOR_ITERACION : process (CLK_I)
  begin
    if rising_edge(CLK_I) then
      if RST_N_I = '0' then
        r_cont_iter <= 0;
      else
        r_cont_iter <= 0;
        if re_state = SM_CALCULATE then
          r_cont_iter <= r_cont_iter + 1;
        end if;
      end if;
    end if;
  end process;

end Behavioral;