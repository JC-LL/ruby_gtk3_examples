entity mux_4to1 is
  port (
    sel : in std_logic_vector(1 downto 0);
    a, b, c, d : in std_logic;
    y : out std_logic
  );
end entity;

architecture rtl of mux_4to1 is
begin
  with sel select
    y <= a when "00",
         b when "01",
         c when "10",
         d when "11",
         '0' when others;
end architecture;