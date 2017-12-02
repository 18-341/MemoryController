`default_nettype none

module HWTB (
  input logic clock, reset_n,

  output logic [21:0] addr_out,
  output logic [15:0] data_out,
  output logic we_out, re_out,

  input logic [15:0] data_in,
  input logic data_in_valid,
  input logic phase_ready,

  output logic done,
  output logic phase0_start, phase1_start, phase2_start, phase3_start,

  input logic [9:0] SW,
  output logic [3:0] LEDG,
  output logic [6:0] HEX0_D, HEX1_D, HEX2_D, HEX3_D);

  logic [15:0] hex_display;

  logic [10:0] bromA_addr, bromB_addr;
  logic bromA_rden, bromB_rden;
  logic [32:0] bromA_data, bromB_data;

  logic [9:0] issued_count;
  logic inc_issued_count, clr_issued_count;
  logic [9:0] completed_count;
  logic inc_completed_count, clr_completed_count;
  logic [31:0] tick_count[4];
  logic inc_tick_count[4];
  logic clr_tick_count;
  logic [15:0] correct_count[4];
  logic inc_correct_count[4];
  logic clr_correct_count;

  enum {
      IDLE, PHASE0_WR, PHASE0_RD, PHASE1_WR, PHASE1_RD, PHASE2_WR, PHASE2_RD,
      PHASE3_WR, PHASE3_RD, REPORT, ERROR, TIMEOUT
  } current_state, next_state;

  DPROM2048
    addr_rom (.clock(clock),
              .addrA(bromA_addr), .addrB(bromB_addr),
              .rdenA(bromA_rden), .rdenB(bromB_rden),
              .qA(bromA_data), .qB(bromB_data));

  HextoSevenSegment
    hex0 (.hex(hex_display[3:0]), .segment(HEX0_D)),
    hex1 (.hex(hex_display[7:4]), .segment(HEX1_D)),
    hex2 (.hex(hex_display[11:8]), .segment(HEX2_D)),
    hex3 (.hex(hex_display[15:12]), .segment(HEX3_D));

  assign LEDG[0] = correct_count[0] == 1;
  assign LEDG[1] = correct_count[1] == 10;
  assign LEDG[2] = correct_count[2] == 1000;
  assign LEDG[3] = correct_count[3] == 1000;

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) issued_count <= '0;
    else if (clr_issued_count) issued_count <= '0;
    else if (inc_issued_count) issued_count <= issued_count + 1'd1;
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) completed_count <= '0;
    else if (clr_completed_count) completed_count <= '0;
    else if (inc_completed_count) completed_count <= completed_count + 1'd1;
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      tick_count <= '{'0, '0, '0, '0};
    end else if (clr_tick_count) begin
      tick_count <= '{'0, '0, '0, '0};
    end else begin
      if (inc_tick_count[0]) begin
        tick_count[0] <= tick_count[0] + 1'd1;
      end else if (inc_tick_count[1]) begin
        tick_count[1] <= tick_count[1] + 1'd1;
      end else if (inc_tick_count[2]) begin
        tick_count[2] <= tick_count[2] + 1'd1;
      end else if (inc_tick_count[3]) begin
        tick_count[3] <= tick_count[3] + 1'd1;
      end
    end
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      correct_count <= '{'0, '0, '0, '0};
    end else if (clr_correct_count) begin
      correct_count <= '{'0, '0, '0, '0};
    end else begin
      if (inc_correct_count[0]) begin
        correct_count[0] <= correct_count[0] + 1'd1;
      end else if (inc_correct_count[1]) begin
        correct_count[1] <= correct_count[1] + 1'd1;
      end else if (inc_correct_count[2]) begin
        correct_count[2] <= correct_count[2] + 1'd1;
      end else if (inc_correct_count[3]) begin
        correct_count[3] <= correct_count[3] + 1'd1;
      end
    end
  end

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) current_state <= IDLE;
    else current_state <= next_state;
  end

  always_comb begin
    addr_out = '0;
    data_out = '0;
    re_out = 1'b0;
    we_out = 1'b0;

    done = 1'b0;
    phase0_start = 1'b0;
    phase1_start = 1'b0;
    phase2_start = 1'b0;
    phase3_start = 1'b0;

    hex_display = '0;

    bromA_addr = '0;
    bromB_addr = '0;
    bromA_rden = 1'b0;
    bromB_rden = 1'b0;

    inc_issued_count = 1'b0;
    clr_issued_count = 1'b0;
    inc_completed_count = 1'b0;
    clr_completed_count = 1'b0;
    inc_tick_count = '{1'b0, 1'b0, 1'b0, 1'b0};
    clr_tick_count = 1'b0;
    inc_correct_count = '{1'b0, 1'b0, 1'b0, 1'b0};
    clr_correct_count = 1'b0;

    next_state = current_state;


    unique case (current_state)
      IDLE: begin
        phase0_start = 1'b1;
        next_state = PHASE0_WR;
      end

      PHASE0_WR: begin
        if (phase_ready) begin
          addr_out = 22'd18341;
          data_out = 16'hbe_ef;
          we_out = 1'b1;

          inc_tick_count[0] = 1'b1;

          next_state = PHASE0_RD;
        end
      end

      PHASE0_RD: begin
        if (issued_count == 1 && phase_ready) begin
          clr_issued_count = 1'b1;
          clr_tick_count = 1'b1;
          clr_correct_count = 1'b1;
          next_state = ERROR;
        end else if (tick_count[0] == 32'hff_ff_ff_ff) begin
          clr_issued_count = 1'b1;
          clr_tick_count = 1'b1;
          clr_correct_count = 1'b1;
          next_state = TIMEOUT;
        end else begin
          inc_tick_count[0] = 1'b1;

          if (phase_ready) begin
            addr_out = 22'd18341;
            re_out = 1'b1;

            inc_issued_count = 1'b1;
          end

          if (data_in_valid) begin
            inc_correct_count[0] = data_in == 16'hbe_ef;

            phase1_start = 1'b1;

            clr_issued_count = 1'b1;
            next_state = PHASE1_WR;
          end
        end
      end

      PHASE1_WR: begin
        if (phase_ready) begin
          unique case (issued_count)
            0: begin
              addr_out = 22'd18341;
              data_out = 16'h00_00;
            end

            1: begin
              addr_out = 22'd83411;
              data_out = 16'h11_11;
            end

            2: begin
              addr_out = 22'd34118;
              data_out = 16'h22_22;
            end

            3: begin
              addr_out = 22'd41183;
              data_out = 16'h33_33;
            end

            4: begin
              addr_out = 22'd11834;
              data_out = 16'h44_44;
            end

            5: begin
              addr_out = 22'b100000_01010101_01010101;
              data_out = 16'h55_55;
            end

            6: begin
              addr_out = 22'b010000_10101010_10101010;
              data_out = 16'h66_66;
            end

            7: begin
              addr_out = 22'b001000_00000000_11111111;
              data_out = 16'h77_77;
            end

            8: begin
              addr_out = 22'b111111_11111111_11111111;
              data_out = 16'h88_88;
            end

            9: begin
              addr_out = 22'b000000_00000000_00000000;
              data_out = 16'h99_99;
            end

            default: begin
            end
          endcase

          we_out = 1'b1;

          inc_tick_count[1] = 1'b1;

          if (issued_count == 9) begin
            clr_issued_count = 1'b1;
            next_state = PHASE1_RD;
          end else begin
            inc_issued_count = 1'b1;
          end
        end else if (tick_count[1] != 0) begin
          inc_tick_count[1] = 1'b1;
        end
      end

      PHASE1_RD: begin
        if (issued_count == 10 && phase_ready) begin
          clr_issued_count = 1'b1;
          clr_completed_count = 1'b1;
          clr_tick_count = 1'b1;
          clr_correct_count = 1'b1;
          next_state = ERROR;
        end else if (tick_count[1] == 32'hff_ff_ff_ff) begin
          clr_issued_count = 1'b1;
          clr_completed_count = 1'b1;
          clr_tick_count = 1'b1;
          clr_correct_count = 1'b1;
          next_state = TIMEOUT;
        end else begin
          inc_tick_count[1] = 1'b1;

          if (phase_ready) begin
            unique case (issued_count)
              0: addr_out = 22'd18341;
              1: addr_out = 22'd83411;
              2: addr_out = 22'd34118;
              3: addr_out = 22'd41183;
              4: addr_out = 22'd11834;
              5: addr_out = 22'b100000_01010101_01010101;
              6: addr_out = 22'b010000_10101010_10101010;
              7: addr_out = 22'b001000_00000000_11111111;
              8: addr_out = 22'b111111_11111111_11111111;
              9: addr_out = 22'b000000_00000000_00000000;
              default: ;
            endcase

            re_out = 1'b1;

            inc_issued_count = 1'b1;
          end

          if (data_in_valid) begin
            inc_completed_count = 1'b1;

            unique case (completed_count)
              0: inc_correct_count[1] = data_in == 16'h00_00;
              1: inc_correct_count[1] = data_in == 16'h11_11;
              2: inc_correct_count[1] = data_in == 16'h22_22;
              3: inc_correct_count[1] = data_in == 16'h33_33;
              4: inc_correct_count[1] = data_in == 16'h44_44;
              5: inc_correct_count[1] = data_in == 16'h55_55;
              6: inc_correct_count[1] = data_in == 16'h66_66;
              7: inc_correct_count[1] = data_in == 16'h77_77;
              8: inc_correct_count[1] = data_in == 16'h88_88;
              9: inc_correct_count[1] = data_in == 16'h99_99;
              default: ;
            endcase

            if (completed_count == 9) begin
              phase2_start = 1'b1;

              clr_issued_count = 1'b1;
              clr_completed_count = 1'b1;
              next_state = PHASE2_WR;
            end
          end
        end
      end

      PHASE2_WR: begin
        if (phase_ready) begin
          addr_out = bromA_data[31:10];
          data_out = {6'h00, bromA_data[9:0]};
          we_out = 1'b1;

          inc_tick_count[2] = 1'b1;

          if (issued_count == 999) begin
            bromA_addr = {1'b1, 10'd0};
            bromB_addr = {1'b1, 10'd0};
            bromA_rden = 1'b1;
            bromB_rden = 1'b1;

            clr_issued_count = 1'b1;
            next_state = PHASE2_RD;
          end else begin
            bromA_addr = {1'b0, issued_count + 1'd1};
            bromA_rden = 1'b1;

            inc_issued_count = 1'b1;
          end
        end else if (tick_count[2] != 0) begin
          inc_tick_count[2] = 1'b1;
        end
      end

      PHASE2_RD: begin
        if (issued_count == 1000 && phase_ready) begin
          clr_issued_count = 1'b1;
          clr_completed_count = 1'b1;
          clr_tick_count = 1'b1;
          clr_correct_count = 1'b1;
          next_state = ERROR;
        end else if (tick_count[2] == 32'hff_ff_ff_ff) begin
          clr_issued_count = 1'b1;
          clr_completed_count = 1'b1;
          clr_tick_count = 1'b1;
          clr_correct_count = 1'b1;
          next_state = TIMEOUT;
        end else begin
          inc_tick_count[2] = 1'b1;

          if (phase_ready) begin
            addr_out = bromA_data[31:10];
            re_out = 1'b1;

            bromA_addr = {1'b1, issued_count + 1'd1};
            bromA_rden = 1'b1;

            inc_issued_count = 1'b1;
          end

          if (data_in_valid) begin
            inc_completed_count = 1'b1;
            inc_correct_count[2] = data_in == {6'h00, bromB_data[9:0]};

            if (completed_count == 999) begin
              phase3_start = 1'b1;

              bromA_addr = {1'b0, 10'd0};
              bromB_addr = {1'b0, 10'd0};
              bromA_rden = 1'b1;
              bromB_rden = 1'b1;

              clr_issued_count = 1'b1;
              clr_completed_count = 1'b1;
              next_state = PHASE3_WR;
            end else begin
              bromB_addr = {1'b1, completed_count + 1'd1};
              bromB_rden = 1'b1;
            end
          end
        end
      end

      PHASE3_WR: begin
        if (phase_ready) begin
          addr_out = {12'h0_00, issued_count};
          data_out = {6'h00, bromA_data[9:0]};
          we_out = 1'b1;

          inc_tick_count[3] = 1'b1;

          if (issued_count == 999) begin
            bromA_addr = {1'b0, 10'd0};
            bromA_rden = 1'b1;

            clr_issued_count = 1'b1;
            next_state = PHASE3_RD;
          end else begin
            bromA_addr = {1'b0, issued_count + 1'd1};
            bromA_rden = 1'b1;

            inc_issued_count = 1'b1;
          end
        end else if (tick_count[3] != 0) begin
          inc_tick_count[3] = 1'b1;
        end
      end

      PHASE3_RD: begin
        if (issued_count == 1000 && phase_ready) begin
          clr_issued_count = 1'b1;
          clr_completed_count = 1'b1;
          clr_tick_count = 1'b1;
          clr_correct_count = 1'b1;
          next_state = ERROR;
        end else if (tick_count[3] == 32'hff_ff_ff_ff) begin
          clr_issued_count = 1'b1;
          clr_completed_count = 1'b1;
          clr_tick_count = 1'b1;
          clr_correct_count = 1'b1;
          next_state = TIMEOUT;
        end else begin
          inc_tick_count[3] = 1'b1;

          if (phase_ready) begin
            addr_out = {12'h0_00, issued_count};
            re_out = 1'b1;

            inc_issued_count = 1'b1;
          end

          if (data_in_valid) begin
            inc_completed_count = 1'b1;
            inc_correct_count[3] = data_in == {6'h00, bromA_data[9:0]};

            if (completed_count == 999) begin
              done = 1'b1;

              bromA_addr = {1'b0, 10'd0};
              bromA_rden = 1'b1;

              clr_issued_count = 1'b1;
              clr_completed_count = 1'b1;
              next_state = REPORT;
            end else begin
              bromA_addr = {1'b0, completed_count + 1'd1};
              bromA_rden = 1'b1;
            end
          end
        end
      end

      REPORT: begin
        /*
         * Switch 9
         *   0 clock count
         *   1 correctness count
         * Switch 8
         *   0 clock count low
         *   1 clock count high
         * Switch 1:0
         *     phase
         */
        if (SW[9]) begin
          hex_display = correct_count[SW[1:0]];
        end else begin
          if (SW[8]) hex_display = tick_count[SW[1:0]][31:16];
          else hex_display = tick_count[SW[1:0]][15:0];
        end
      end

      ERROR: begin
        hex_display = 16'hde_ad;
      end

      TIMEOUT: begin
        hex_display = 16'h0b_ad;
      end
    endcase
  end

endmodule : HWTB

module HextoSevenSegment (
  input logic [3:0] hex,
  output logic [6:0] segment);

  always_comb begin
    case(hex)
      4'h0: segment = 7'b1000000;
      4'h1: segment = 7'b1111001;
      4'h2: segment = 7'b0100100;
      4'h3: segment = 7'b0110000;
      4'h4: segment = 7'b0011001;
      4'h5: segment = 7'b0010010;
      4'h6: segment = 7'b0000010;
      4'h7: segment = 7'b1111000;
      4'h8: segment = 7'b0000000;
      4'h9: segment = 7'b0011000;
      4'ha: segment = 7'b0001000;
      4'hb: segment = 7'b0000011;
      4'hc: segment = 7'b1000110;
      4'hd: segment = 7'b0100001;
      4'he: segment = 7'b0000110;
      4'hf: segment = 7'b0001110;
    endcase
  end
endmodule : HextoSevenSegment

module DPROM2048 (
  input logic clock,
  input logic [10:0] addrA, addrB,
  input logic rdenA, rdenB,
  output logic [31:0] qA, qB);

  /* logic [31:0] M[2048]; */

  /* initial begin */
  /*   $readmemh("randmem.dat", M, 0, 2048); */
  /* end */

  /* always_comb */
  /*   qA = M[addrA]; */
  /*   qB = M[addrB]; */
  /* end */

  altsyncram
    altsyncram_component (.clock0(clock),
                          .wren_a(1'b0), .wren_b(1'b0),
                          .rden_a(rdenA), .rden_b(rdenB),
                          .address_b(addrB), .address_a(addrA),
                          .q_b(qB), .q_a(qA));

  defparam
    altsyncram_component.address_reg_b = "CLOCK0",
    altsyncram_component.clock_enable_input_a = "BYPASS",
    altsyncram_component.clock_enable_input_b = "BYPASS",
    altsyncram_component.clock_enable_output_a = "BYPASS",
    altsyncram_component.clock_enable_output_b = "BYPASS",
    altsyncram_component.indata_reg_b = "CLOCK0",
    altsyncram_component.init_file = "mem_ctrlr.mif",
    altsyncram_component.intended_device_family = "Cyclone III",
    altsyncram_component.lpm_type = "altsyncram",
    altsyncram_component.numwords_a = 2048,
    altsyncram_component.numwords_b = 2048,
    altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
    altsyncram_component.outdata_aclr_a = "NONE",
    altsyncram_component.outdata_aclr_b = "NONE",
    altsyncram_component.outdata_reg_a = "UNREGISTERED",
    altsyncram_component.outdata_reg_b = "UNREGISTERED",
    altsyncram_component.power_up_uninitialized = "FALSE",
    altsyncram_component.widthad_a = 11,
    altsyncram_component.widthad_b = 11,
    altsyncram_component.width_a = 32,
    altsyncram_component.width_b = 32,
    altsyncram_component.width_byteena_a = 1,
    altsyncram_component.width_byteena_b = 1,
    altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0";
endmodule : DPROM2048
