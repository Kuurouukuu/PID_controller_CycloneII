//`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:29:09 03/10/2020 
// Design Name: 
// Module Name:    led 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: TODO: Check the Encoder count value to verify the
// precision
//
//////////////////////////////////////////////////////////////////////////////////
module led_velocity(Clk50, rst, i_A, i_B, o_controlPin, LED, o_uart_tx
    );
	 
	input Clk50;
	input i_A, i_B;
	input rst;
	output [1:0] o_controlPin;
	output [7:0] LED;
	output o_uart_tx;
	
	wire w_uartFull;
	wire w_Clk_5;
	wire w_Clk_11;
	wire w_Direction;
	wire DV;
	wire w_Clk_10;
	wire [15:0] w_velocity;
	wire [15:0] w_position;
	wire debounced_kp, debounced_ki, debounced_kd, debounced_hold;
	wire debounced_A, debounced_B;
	wire [15:0] w_un;
	wire w_pwm_out;	
	wire [1:0] w_PWM_CW;
	wire [1:0] w_PWM_CCW;
	wire [15:0] w_error;
	wire w_of;	
	wire [31:0] w_probe; // For Debugging
	wire [31:0] pulse_count;
	wire [15:0] w_pwmInputData;


//	Register declaration	
	reg [15:0] w_setpoint = 'd0; // pulse per 11 miliseconds
	initial w_setpoint = 'd0;
	reg [1:0] r_controllerPin = 'd0;
	reg [15:0] r_error_unsigned = 'd0;
	reg [15:0] r_kp = 16'd5;
	initial r_kp = 16'd5;
	reg [15:0] r_kd = 16'd0;
	reg [15:0] r_ki = 16'd2;
	reg [15:0] r_ki_pidInput = 'd2;
	reg [7:0] r_LED;
	reg start;
	reg Clk_10;
	reg [12:0] value = 'd500;
	reg Clk_5;
	reg [23:0] counter = 'd0, counter2 = 'd0; 
	reg [15:0] w_processvalue = 'd0;
	reg Clk_50ms = 'd0;
	reg [10:0] r_readAddr = 'd0;
	reg r_LEDComplete = 'b0;
	reg Clk_11 = 'b0;
	reg i_clk_sp;
	
	
	pllGenerator mainPLL(
		.areset('b0),
		.inclk0(Clk50),
		.c0(Clk),
		.locked()
	); // Generate 12Mhz clock for backward compatibility with Elbert Numato V2
	
	quad decoder(
		.quadA(debounced_A),
		.quadB(debounced_B),
		.clk(Clk),
		.count(w_position),
		.rst(~debounced_reset),
		.o_velocity(w_velocity),
		.count2(pulse_count)
	);
	
	DeBounce debouncer0(
		.clk(Clk),
		.button_in(rst),
		.DB_out(debounced_reset),
		.n_reset(1'b1)
	);

	DeBounce debouncerA(
		.clk(Clk),
		.button_in(i_A),
		.DB_out(debounced_A),
		.n_reset(1'b1)
	);
	
	DeBounce debouncerB(
		.clk(Clk),
		.button_in(i_B),
		.DB_out(debounced_B),
		.n_reset(1'b1)
	);

	inputRam inputRAMData(
		.address(r_readAddr),
		.clock(Clk),
		.data(),
		.wren('b0),
		.q(w_pwmInputData));
	
	pwm pwmGenerator(
		.Clk(Clk), 
		.pwm_in(w_un), 
		.pwm_out(w_pwm_out)
	);

	PID pidController(
		.probe(w_probe),
		.i_clk(Clk),
		.i_rst(~debounced_reset),
		.i_clk_sp(Clk_5),
		.o_un(w_un),
		.o_valid(w_pidValid),
		.sp(w_setpoint),
		.pv(w_processvalue),
		.kp(r_kp),
		.kd(r_kd),
		.ki(r_ki_pidInput),
		.overflow(w_of)
	);

// Sequential block
	always@*
	begin
		w_processvalue = w_velocity;
		w_setpoint = w_pwmInputData;
	end
		
	always@(negedge debounced_reset)
	begin
		r_kp <= 16'd5;
		r_kd <= 16'd0;
		r_ki <= 16'd2;
		r_ki_pidInput <= 'd2;
	end
	
	// Frequency division using counter
	
	 always@(posedge Clk)
	 begin
		counter <= counter+1;			
		Clk_5 <= counter[12]; // Sampling frequency
		Clk_10 <= counter[13]; //732 hezt
		Clk_11 <= counter[16]; // 11ms sampling time
	 end
	 
	 always@(posedge Clk)
	 begin
	 if (counter2 == 'h493E0) //generate 20Hz clock
		begin
			counter2 <= 'd0;
			Clk_50ms <= ~Clk_50ms;
		end
		else
			counter2 <= counter2+'d1;
	 end
	 
	 /*
	 * This block move to the next address of the Ram each Ts. 
	 * Ram contains desired speed value according to S-curve
	 */

	always@(posedge Clk_11) // 11ms, update time
	begin
		if (r_readAddr > 'd400)
		begin
			r_LEDComplete <= 'b1;
			r_readAddr <= 'd0;
		end
		else
			r_readAddr <= r_readAddr + 'd1;
	end


   // find abs error
	always @(posedge Clk)	
		if (w_error[15]==1'b1) 
			r_error_unsigned <= ((~w_error)+(1'b1)); 
		else
			r_error_unsigned <= w_error;
	
	 
	 // Update K_i to prevent windup

/*	 always@(Clk)
	 begin
		r_ki_pidInput <= (w_of) ? 'd0 : r_ki;
	 end*/
	 
	 
	//Check error and fire PWM based on error. 
	 always @(posedge Clk)
	 begin
		if ((w_setpoint<14'd10)) // Too small, cannot control, turn it off
			begin
				r_controllerPin<=2'd0;
				r_LED <= 'b00000001;
			end
		else
				begin 
					r_controllerPin <= w_PWM_CW;
					r_LED <= 'b00000100;
				end
	 end
	
	
	// Assignment section
	assign w_error = w_velocity - w_pwmInputData; // control Velocity first TODO: generalize, control position	
	assign w_PWM_CW[1:0]={w_pwm_out,1'b0}; // Concatenation 2 output for 2 port
	assign w_PWM_CCW[1:0]={1'b0,w_pwm_out};
	assign w_Clk_5 = Clk_5;
	assign w_Clk_10 = Clk_10; //Div by 2^16
	assign w_Clk_11 = Clk_11; // 11 ms sampling time
	assign o_controlPin = r_controllerPin;


	// Implement Uart module for communication
	reg [0:7] r_uart_data_in, r_uart_data_prev;
	reg r_uart_update = 'b0, r_uart_update_prev, rDataUpdate = 'b0, rDataUpdatePrev;
	reg [1:0] temp_counter = 'b0;
	reg [31:0] dataIn = 'd0;
	reg [2:0] sSample = 'd8, sSampleNext = 'd8;
	reg rUartWrite = 'b0;
	reg [31:0] dataTemp = 'h0000;
	initial dataTemp = 32'h0000;
	reg [15:0] r_velocity, r_pwmInputData;

	wire w_uart_write, wDataUpdate;
	wire [3:0] probe;
	
	/*
	* This block is used for buffering the data before UART sample it.
	*/
	always@(posedge Clk)
	begin
		r_velocity <= w_velocity;
		r_pwmInputData <= w_pwmInputData;
	end
	
	always@(posedge Clk_10)
	begin
//		if (w_velocity == 'd0)
//			dataTemp <= pulse_count;
//		else
			dataTemp <= {w_processvalue, w_setpoint}; // Determine what you want to send
		rDataUpdate <= ~rDataUpdate; // Pull the update High for one cycle, request UART tranmission
	end
	
	/*
	* Transfer 32-bit of data in 8-bit UART requires seperate the data
	* into smaller chunk and send 8-bit each time.
	* This FSM block is used to seperate the data
	*/		
	always@(*)
	begin
		case (sSample)
			3'd1: begin
				r_uart_data_in = dataTemp[7:0];
				sSampleNext = 3'd2;
				r_uart_update = ~r_uart_update;
				rUartWrite = 'b1;
			end
			3'd2: begin
				r_uart_data_in = dataTemp[15:8];
				sSampleNext = 3'd3;
				r_uart_update = ~r_uart_update;
				rUartWrite = 'b1;
			end
			3'd3: begin
				r_uart_data_in = dataTemp[23:16];
				sSampleNext = 3'd4;
				r_uart_update = ~r_uart_update;
				rUartWrite = 'b1;
			end			
			3'd4: begin
				r_uart_data_in = dataTemp[31:24];
				sSampleNext = 3'd5; // Jump to default
				r_uart_update = ~r_uart_update;
				rUartWrite = 'b1;
			end
			default: begin // Wait until rDataUpdate high for one clock cycle
				rUartWrite = 'b0;
				if (rDataUpdate == ~rDataUpdatePrev) // If there is data change
				begin
					sSampleNext = 3'd1; // Start latching
				end
				else
					sSampleNext = sSample; // Stay in default
			end
			endcase
	end
	
	always@(posedge Clk) // Update buffer at maximum speed
	begin
			sSample <= sSampleNext;
	end
	
	always@(posedge Clk)
	begin
		rDataUpdatePrev <= rDataUpdate;
		r_uart_update_prev <= r_uart_update;
	end

	// End of latching FSM	

	// Initialize UART Module	
	uart_top myUart(
		.tx(o_uart_tx),
		.data_in(r_uart_data_in),
		.address(r_uart_address),
		.i_wr_uart(w_uart_write),
		.o_full(w_uartFull),
		.clk(Clk),
		.reset('b0),
		.probe(probe)
	);
	
	// Assignment section	
	assign w_uart_write = rUartWrite;
	assign wDataUpdate = ~(rDataUpdatePrev == rDataUpdate);
	assign LED[0] = o_controlPin[0];
	assign LED[1] = o_controlPin[1];
	
endmodule
