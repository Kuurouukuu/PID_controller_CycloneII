module ramTb;

//Input
reg	[10:0]  address;
reg	  clock;
reg	[15:0]  data;
reg	  wren;

//Output
wire [15:0] q;

inputRam UUT(
	.address(address),
	.clock(clock),
	.data(data),
	.wren(wren),
	.q(q));

initial begin
	address = 'b0;
	clock = 'b0;
	data = 'b0;
	wren = 'b0;
	
	#100
	// Wait 100 ns for global reset to finish
	
	forever #1 clock = ~clock;
end

reg [3:0] counter = 'b0;

always@(posedge clock)
begin
	counter <= counter + 'b1;
end

always@(posedge counter[3])
begin
	address <= address + 'b1;
end


endmodule