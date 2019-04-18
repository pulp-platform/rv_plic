// does not support more than 31 interrupt sources at the moment
// for an explanation of the regmap, see also
// see also https://sifive.cdn.prismic.io/sifive%2F834354f0-08e6-423c-bf1f-0cb58ef14061_fu540-c000-v1.0.pdf

module plic_regmap #(
  parameter int NumSource = 31,
  parameter int NumTarget = 2,
  parameter int MaxPrio   = 7
) (
  input  logic [NumSource:0][$clog2(MaxPrio)-1:0]       prio_i,
  output logic [NumSource:0][$clog2(MaxPrio)-1:0]       prio_o,
  output logic [NumSource:0]                            prio_we_o,
  input  logic [NumSource:0]                            ip_i,
  input  logic [NumTarget-1:0][NumSource:0]             ie_i,
  output logic [NumTarget-1:0][NumSource:0]             ie_o,
  output logic [NumTarget-1:0]                          ie_we_o,

  input  logic [NumTarget-1:0][$clog2(MaxPrio)-1:0]     threshold_i,
  output logic [NumTarget-1:0][$clog2(MaxPrio)-1:0]     threshold_o,
  output logic [NumTarget-1:0]                          threshold_we_o,
  input  logic [NumTarget-1:0][$clog2(NumSource+1)-1:0] cc_i,
  output logic [NumTarget-1:0][$clog2(NumSource+1)-1:0] cc_o,
  output logic [NumTarget-1:0]                          cc_we_o,
  output logic [NumTarget-1:0]                          cc_re_o,
  // Bus Interface
  input  reg_intf::reg_intf_req_a32_d32                 req_i,
  output reg_intf::reg_intf_resp_d32                    resp_o
);

always_comb begin
  resp_o.ready   = 1'b1;
  resp_o.rdata   = '0;
  resp_o.error   = '0;
  prio_o         = '0;
  prio_we_o      = '0;
  ie_o           = '0;
  ie_we_o        = '0;
  threshold_o    = '0;
  threshold_we_o = '0;
  cc_o           = '0;
  cc_we_o        = '0;
  cc_re_o        = '0;

  resp_o.error   = 1'b1;

  if (req_i.valid) begin
    if (req_i.write) begin

      // interrupt priority
      // note, source 0 is not writeable
      for (logic[31:0] k=1; k <= NumSource ; k++) begin
        if (req_i.addr == 32'hc000000+k*4) begin
          prio_o[k][$clog2(MaxPrio)-1:0] = req_i.wdata[$clog2(MaxPrio)-1:0];
          prio_we_o[k] = 1'b1;
          resp_o.error = 1'b0;
        end
      end // NumSource

      for (logic[31:0] j=0; j < NumTarget ; j++) begin
        unique case (req_i.addr)
          // interrupt enable register
          // this case needs to be adapted to support more than 31 interrupts
          32'hc002000+j*32'h80: begin
            // note, source 0 is not writeable
            ie_o[j][NumSource:1] = req_i.wdata[NumSource:1];
            ie_we_o[j]   = 1'b1;
            resp_o.error = 1'b0;
          end
          // hart threshold
          32'hc200000+j*32'h1000: begin
            threshold_o[j][$clog2(MaxPrio)-1:0] = req_i.wdata[$clog2(MaxPrio)-1:0];
            threshold_we_o[j] = 1'b1;
            resp_o.error      = 1'b0;
          end
          // hart claim/complete
          32'hc200004+j*32'h1000: begin
            cc_o[j][$clog2(NumSource+1)-1:0] = req_i.wdata[$clog2(NumSource+1)-1:0];
            cc_we_o[j]   = 1'b1;
            resp_o.error = 1'b0;
          end
        endcase // req_i.addr
      end // NumTarget

    end else begin

      for (logic[31:0] k=1; k <= NumSource ; k++) begin
        // interrupt priority
        // note, source 0 is hardwired to 0
        if (req_i.addr == 32'hc000000+k*4) begin
            resp_o.rdata[$clog2(MaxPrio)-1:0] = prio_i[k][$clog2(MaxPrio)-1:0];
            resp_o.error = 1'b0;
        end
      end // NumSource

      // interrupt pending register
      // note, interrupt 0 is hardwired to 0
      if (req_i.addr == 32'hc001000) begin
        resp_o.rdata = ip_i;
        resp_o.error = 1'b0;
      end

      for (logic[31:0] j=0; j < NumTarget ; j++) begin
        unique case (req_i.addr)
          // interrupt enable register
          // this case needs to be adapted to support more than 31 interrupts
          32'hc002000+j*32'h80: begin
            // note, interrupt 0 is hardwired to 0
            resp_o.rdata[NumSource:1] = ie_i[j][NumSource:1];
            resp_o.error = 1'b0;
          end
          // hart threshold
          32'hc200000+j*32'h1000: begin
            resp_o.rdata[$clog2(MaxPrio)-1:0] = threshold_i[j][$clog2(MaxPrio)-1:0];
            resp_o.error      = 1'b0;
          end
          // hart claim/complete
          32'hc200004+j*32'h1000: begin
            resp_o.rdata[$clog2(NumSource+1)-1:0] = cc_i[j][$clog2(NumSource+1)-1:0];
            cc_re_o[j] = 1'b1;
            resp_o.error = 1'b0;
          end
        endcase // req_i.addr
      end // NumTarget
    end
  end
end

//pragma translate_off
initial begin : p_assert
  assert (NumSource<=31) else
    $fatal(1,"Currently only 31 interrupt sources are supported");
end
//pragma translate_on

endmodule
