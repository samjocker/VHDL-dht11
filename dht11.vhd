-- vhdl-linter-disable type-resolved
library ieee ;
use ieee.std_logic_1164.all ;
use ieee.numeric_std.all ;

entity dht11 is
  port (
    clk:in std_logic;
    reset:in std_logic;
    data:inout std_logic:='1';
    seg:out std_logic_vector(6 downto 0);
    com:out std_logic_vector(3 downto 0);
    dot:out std_logic;
    erro:out std_logic
  ) ;
end dht11 ; 

architecture arch of dht11 is
signal clock_ns:std_logic;
signal seg_clk:std_logic;
signal data_value:std_logic_vector(39 downto 0);
type read_mode is (show_mode,start_mode,read_data,delay_mode);
-- signal data_state:std_logic:='1';
signal mode:read_mode:=delay_mode; 
signal temp,humd:integer range 0 to 99;
signal t1,t2,h1,h2:integer range 0 to 9;
signal wrong_data:std_logic:='0';
begin
    clock: process(clk,reset)
    variable c1:integer range 0 to 25:=0;
    variable c_seg:integer range 0 to 100000:=0;
    begin
        if reset='0' then
            c1:=0;
            c_seg:=0;
        elsif clk'event and clk='1' then
            c_seg:=c_seg+1;
            c1:=c1+1;
            if c1=25 then
                clock_ns<=not clock_ns;
                c1:=0;
            end if;
            if c_seg=100000 then
                seg_clk<=not seg_clk;
                c_seg:=0;
            end if;
        end if;
    end process clock;

    data_read: process(clock_ns,reset)
    -- variable mode:read_mode:=delay_mode;
    variable past_time:integer range 0 to 20001:=0;
    variable last_time:integer range 0 to 20001:=0;
    variable data_num:integer range 0 to 200:=0;
    variable now_state:std_logic;
    variable last_state:std_logic:='0';
    variable cd:integer range 0 to 150:=0;
    -- variable last_state:std_logic:='0';
    begin
        if reset='0' then
            mode<=delay_mode;
            past_time:=0;
            cd:=0;
        elsif clock_ns'event and clock_ns='1' then
            case mode is
                when delay_mode=>
                    data<='1';
                    past_time:=past_time+1;
                    if past_time=20000 then
                        past_time:=0;
                        cd:=cd+1;
                        if cd=100 then
                            past_time:=0;
                            cd:=0;
                            mode<=start_mode;
                        end if;
                    end if;
                when start_mode=>
                    past_time:=past_time+1;
                    if past_time<18100 then
                        data<='0';
                    elsif past_time<18140 then
                        data<='1';
                    elsif past_time=18140 then
                        past_time:=0;
                        data<='Z';
                        data_num:=0;
                        last_time:=0;
                        last_state:='0';
                        mode<=read_data;
                    end if;
                when read_data=>
                    data<='Z';
                    now_state:=data;
                    past_time:=past_time+1;
                    if past_time=20000 then
                        past_time:=0;
                        wrong_data<='1';
                        erro<='1';
                        mode<=show_mode;
                    elsif now_state/=last_state and now_state='1' then 
                        last_state:='1';
                        data_num:=data_num+1;
                        if data_num>=2 then 
                            last_time:=past_time;
                        end if;
                    elsif now_state/=last_state and now_state='0'then
                        last_state:='0';
                        if data_num>=2 then
                            if past_time-last_time>65 then
                                data_value<=data_value(38 downto 0)&'1';
                            elsif past_time-last_time<30 then
                                data_value<=data_value(38 downto 0)&'0';
                            else
                                data_value<=data_value(38 downto 0)&'U';
                            end if;
                            if data_num=41 then
                                past_time:=0;
                                last_time:=0;
                                last_state:='0';
                                wrong_data<='0';
                                erro<='0';
                                mode<=show_mode;
                            end if;
                        end if;
                    end if;
                when show_mode=>
                    --show data here
                    past_time:=0;
                    cd:=0;
                    if wrong_data='0' then
                        temp<=to_integer(unsigned(data_value(23 downto 16)));
                        humd<=to_integer(unsigned(data_value(39 downto 32)));
                        t1<=temp mod 10;
                        t2<=temp/10 mod 10;
                        h1<=humd mod 10;
                        h2<=humd/10 mod 10;
                    end if;
                    mode<=delay_mode;
                when others=>null;
            end case;
        end if;    
    end process data_read;

    seg_show: process(seg_clk,reset)
    variable com_count:integer range 0 to 4:=0;
    variable show_num:integer range 0 to 9;
    begin
        if seg_clk'event and seg_clk='1' then
            com_count:=com_count+1;
            if com_count=4 then
                com_count:=0;
            end if;
            case com_count is
                when 0=>
                    show_num:=t2;
                    com<="1110";
                when 1=>
                    show_num:=t1;
                    com<="1101";
                    dot<='1';
                when 2=>
                    show_num:=h2;
                    com<="1011";
                    dot<='0';
                when 3=>
                    show_num:=h1;
                    com<="0111";
                when others=>null;
            end case;
            case show_num is
                when 0=>seg<=not "1000000";
                when 1=>seg<=not "1111001";
                when 2=>seg<=not "0100100";
                when 3=>seg<=not "0110000";
                when 4=>seg<=not "0011001";
                when 5=>seg<=not "0010010";
                when 6=>seg<=not "0000010";
                when 7=>seg<=not "1111000";
                when 8=>seg<=not "0000000";
                when 9=>seg<=not "0011000";
                when others=>seg<="1111110";
            end case;
        end if;
    end process seg_show;
end architecture ;