`timescale 1ns / 1ps


module i2c_master(
	input wire clk,
	input wire rst,
	input wire [6:0] addr,
	input wire [7:0] data_in,
    input wire [7:0] data_in_2,
	input wire enable,
	input wire rw,

	output reg [7:0] data_out,
	output wire ready,

	inout i2c_sda,
	inout i2c_scl
	);
    
	localparam IDLE = 0;
	localparam START = 1;
	localparam ADDRESS = 2;
	localparam READ_ACK = 3;
	localparam READ_ACK2 = 10;
	localparam WRITE_DATA = 4;
	localparam WRITE_ACK = 5;
    localparam WRITE_DATA2 = 9;
	localparam READ_DATA = 6;
	localparam READ_ACK3 = 7;
	localparam STOP = 8;
	
	localparam DIVIDE_BY = 256;

    reg [7:0] DELAY_CONST = 32;

	reg [7:0] state = IDLE;
	reg [7:0] saved_addr;
	reg [7:0] saved_data;
    reg [7:0] saved_data_2;
	reg [7:0] counter;
	reg [15:0] counter2 = 0;
	reg [15:0] counter_independent = 0;
	reg write_enable;
	reg sda_out;
	
//    reg write_enable_undelayed;
//	reg sda_out_undelayed = 1;
	
	reg i2c_scl_enable = 0;

	reg i2c_clk = 1;
	reg i2c_clk_indep = 1;

    localparam HIGH_COUNT = (DIVIDE_BY * 1/4) - 1;  // 25% of the total period
    localparam LOW_COUNT  = (DIVIDE_BY * 3/4) - 1;  // 75% of the total period

	assign ready = ((rst == 0) && (state == IDLE)) ? 1 : 0;
    assign i2c_scl = (i2c_scl_enable == 0 ) ? 1 : i2c_clk_indep;
	assign i2c_sda = (write_enable == 1) ? sda_out : 'bz;
	
	always @(posedge clk) begin
		if (counter2 == (DIVIDE_BY/2) - 1) begin
			i2c_clk <= ~i2c_clk;
			counter2 <= 0;
		end
		else counter2 <= counter2 + 1;

        if (i2c_clk_indep == 1'b1) begin
            if (counter_independent == HIGH_COUNT) begin
                i2c_clk_indep <= 1'b0;   // Transition to low after HIGH_COUNT
                counter_independent <= 0;
            end
            else counter_independent <= counter_independent + 1;
        end
        else begin  // i2c_clk == 1'b0 (low phase)
            if (counter_independent == LOW_COUNT) begin
                i2c_clk_indep <= 1'b1;   // Transition to high after LOW_COUNT
                counter_independent <= 0;
            end
            else counter_independent <= counter_independent + 1;
        end
	
	end
	
	always @(negedge i2c_clk, posedge rst) begin
		if(rst == 1) begin
			i2c_scl_enable <= 0;
		end else begin
			if ((state == IDLE) || (state == START) || (state == STOP)) begin
				i2c_scl_enable <= 0;
			end else begin
				i2c_scl_enable <= 1;
			end
		end
	end


	always @(posedge i2c_clk, posedge rst) begin	
        
        if(rst == 1) begin
			state <= IDLE;
		end		
		else begin
			case(state)
			
				IDLE: begin
					if (enable) begin
						state <= START;
						saved_addr   <= {addr, rw};
						saved_data   <= data_in;
						saved_data_2 <= data_in_2;
					end
					else state <= IDLE;
				end

				START: begin
					counter <= 7;
					state <= ADDRESS;
				end

				ADDRESS: begin
					if (counter == 0) begin 
						state <= READ_ACK;
					end else counter <= counter - 1;
				end

				READ_ACK: begin
                    counter <= 7;
                    state <= WRITE_DATA;
				end

				WRITE_DATA: begin
					if(counter == 0) begin
						state <= READ_ACK2;
					end else counter <= counter - 1;
				end
				
                READ_ACK2: begin
                    counter <= 7;
                    state <= WRITE_DATA2;
				end

				WRITE_DATA2: begin
					if(counter == 0) begin
						state <= READ_ACK3;
					end else counter <= counter - 1;
				end
				
				READ_ACK3: begin
					if ((i2c_sda == 0) && (enable == 1)) state <= IDLE;
					else state <= STOP;
				end

				READ_DATA: begin
					data_out[counter] <= i2c_sda;
					if (counter == 0) state <= WRITE_ACK;
					else counter <= counter - 1;
				end
				
				WRITE_ACK: begin
					state <= STOP;
				end

				STOP: begin
					state <= IDLE;
				end
			endcase
		end
	end
	
	always @(negedge i2c_clk, posedge rst) begin
		if(rst == 1) begin
			write_enable <= 1;
			sda_out <= 1;
		end else begin
			case(state)
				
				START: begin
					write_enable <= 1;
					sda_out <= 0;
				end
				
				ADDRESS: begin
					sda_out <= saved_addr[counter];
				end
				
				READ_ACK: begin
					write_enable <= 0;
				end

				READ_ACK2: begin
					write_enable <= 0;
				end
				
                READ_ACK3: begin
					write_enable <= 0;
				end
				
				WRITE_DATA: begin 
					write_enable <= 1;
					sda_out <= saved_data[counter];
				end
				
				WRITE_ACK: begin
					write_enable <= 1;
					sda_out <= 0;
				end
    
                WRITE_DATA2: begin
					write_enable <= 1;
					sda_out <= saved_data_2[counter];
				end
				
				READ_DATA: begin
					write_enable <= 0;				
				end
				
				STOP: begin
					write_enable <= 1;
					sda_out <= 1;
				end
			endcase
		end
	end

endmodule
