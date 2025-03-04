`timescale 1ns/1ps

module ConfigFSM (CLK, WriteData, WriteStrobe, Reset, FrameAddressRegister, LongFrameStrobe, RowSelect);
	parameter NumberOfRows = 12;
	parameter RowSelectWidth = 5;
	parameter FrameBitsPerRow = 32;
	parameter desync_flag = 20;

	input CLK; 
	
	input [31:0] WriteData;
	input WriteStrobe;
	input Reset;
	
	output reg [FrameBitsPerRow-1:0] FrameAddressRegister;
	output reg LongFrameStrobe = 0;
	output reg [RowSelectWidth-1:0] RowSelect;
	
	reg FrameStrobe = 0;
	//signal FrameShiftState : integer range 0 to (NumberOfRows + 2);
	reg [4:0] FrameShiftState = 0;

	//FSM
	reg [1:0] state = 0;
	reg old_reset;
	always @ (posedge CLK) begin : P_FSM
		old_reset <= Reset;
		FrameStrobe <= 1'b0;
		// we only activate the configuration after detecting a 32-bit aligned pattern "x"FAB0_FAB1"
		// this allows placing the com-port header into the file and we can use the same file for parallel or UART configuration
		// this also allows us to place whatever metadata, the only point to remeber is that the pattern/file needs to be 4-byte padded in the header
		if ((old_reset == 1'b0) && (Reset == 1'b1)) begin // reset all on ComActive posedge
			state <= 0;
			FrameShiftState <= 0;
		end else begin
			case(state)
				0: begin // unsynched
					if(WriteStrobe == 1'b1) begin // if writing enabled
						if (WriteData == 32'hFAB0_FAB1) begin // fire only after seeing pattern 0xFAB0_FAB1
							state <= 1; //go to synched state
						end
					end
				end
				1: begin // SyncState read header
					if(WriteStrobe == 1'b1) begin// if writing enabled
						if(WriteData[desync_flag] == 1'b1) begin // desync
							state <= 0; //desynced
						end else begin
							FrameAddressRegister <= WriteData;
							FrameShiftState <= NumberOfRows  ;
							state <= 2; //writing frame data
						end
					end
				end
				2: begin
					if(WriteStrobe == 1'b1) begin// if writing enabled
						FrameShiftState <= FrameShiftState -1 ;
						if(FrameShiftState == 1) begin // on last frame
							FrameStrobe <= 1'b1; //trigger FrameStrobe
							state <= 1; // we go to synched state waiting for next frame or desync
						end
					end
				end
			endcase
		end
	end
	
	always @ (*) begin
		if(WriteStrobe) begin // if writing active
			RowSelect = #1 FrameShiftState; // we write the frame
		end else begin
			RowSelect = #1 {RowSelectWidth{1'b1}}; //otherwise, we write an invalid frame
		end
	end
	
	reg oldFrameStrobe = 0;
	always @ (posedge CLK) begin : P_StrobeREG
		oldFrameStrobe <= FrameStrobe;
		LongFrameStrobe <= (FrameStrobe || oldFrameStrobe);
	end//CLK
	
endmodule
