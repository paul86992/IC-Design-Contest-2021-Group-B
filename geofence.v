module geofence ( clk,reset,X,Y,R,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
input [10:0] R;
output valid;
output is_inside;
//reg valid;
//reg is_inside;

parameter save = 0, sort = 1, inorout=2; 

reg [2:0] state , nstate;
reg [2:0] savecnt;
reg [3:0] sortcnt;
reg [3:0] inoroutcnt;
reg  [2:0] index0;
wire [2:0] index1;

always@(*)begin
	if(reset)begin
		nstate = save;
	end
	else begin
		case(state)
			save   : nstate = (savecnt == 5)?sort:save;
			sort   : nstate = (index0==4 && index1 ==5)?inorout:sort;
			inorout: nstate = (valid)?save:inorout;			
		endcase
	end
end

always@(posedge clk or posedge reset)begin
	if(reset)
		state <= save;
	else
		state <= nstate;
end


// command
// valid >>>>>>>>>>> save

//***** for debug *****
/* reg [8:0] cnt;
always@(posedge clk or posedge reset)begin
	if(reset)
		cnt <= 0;
	else if(savecnt == 1)
		cnt <= cnt + 1;
end */
//*************** state save *************** 
 
always@(posedge clk or posedge reset)begin
	if(reset)
		savecnt <= 0;
	else if(state == save)
		savecnt <= savecnt + 1;
	else 
		savecnt <= 0;
end

//***** preserve the inf *****

reg [9:0]  xcoor [5:0];
reg [9:0]  ycoor [5:0];
reg [10:0] dis   [5:0];

integer i, j, m, n; 

always@(posedge clk or posedge reset)begin
	if(reset)begin
		for(i=0;i<=5;i=i+1)begin
			xcoor[i] <= 0;
			ycoor[i] <= 0;
			dis[i] <= 0;
		end
	end
	else if(state == save)begin
		xcoor[5-savecnt] <= X;
		ycoor[5-savecnt] <= Y;
		dis[5-savecnt] <= R;
	end
end

//*************** state sort ***************


// counter  0 1 2 3 4 0 1 2 3 4 ...... 0 1 2 3 4
// index0:  0 0 0 0 0 1 1 1 1 1 ...... 4 4 4 4 4
// index1:  0 1 2 3 4 0 1 2 3 4 ...... 0 1 2 3 4
// vecter A = (Ax,Ay) , B = (Bx,By) 

always@(posedge clk or posedge reset)begin
	if(reset)begin
		sortcnt <= 0;
		index0 <= 0;
	end
	else if(state == sort)begin
		if(sortcnt == 6)begin
			sortcnt <= 0;
			index0 = index0 + 1;
		end	
		else
			sortcnt <= sortcnt + 1;
	end
	else begin
		sortcnt <= 0;
		index0 <= 0;
	end
end

assign index1 = sortcnt;

//********************************************

wire signed [13:0] Ax, Ay, Bx, By;

assign Ax = xcoor[index0] - xcoor[5];  // set (X[5],Y[5]) as the referent point
assign Ay = ycoor[index0] - ycoor[5];

assign Bx = xcoor[index1] - xcoor[5];
assign By = ycoor[index1] - ycoor[5];

wire signed [20:0] outprod;
wire notcount;

assign outprod  = Ax*By - Bx*Ay;
assign notcount = (index0 == index1)?1:0;

reg [2:0] left  ; 
reg [2:0] right ; 
always@(posedge clk or posedge reset)begin
	if(reset)begin
		left <= 0;
		right <= 0;
	end
	else if(state == sort)begin
		if(!notcount)begin
			if(outprod>0 &&sortcnt<=5)
				left  <= left + 1;
			else if(outprod<0&&sortcnt<=5)
				right <= right+ 1;
			else if (sortcnt == 5)begin
				left <= 0;
				right<= 0;

			end						
		end
	end
	else begin

		left <= 0;
		right <= 0;
	end
end

reg [9:0] Xnew[5:0];
reg [9:0] Ynew[5:0];
reg [10:0] Rnew[5:0];

always@(posedge clk or posedge reset)begin
	if(reset)begin
		for(j=0;j<=5;j=j+1)begin
			Xnew[j] <= 0;
			Ynew[j] <= 0;
			Rnew[j] <= 0;
		end
	end
	else if(state == sort)begin
		Xnew[5] <= xcoor[5];
		Ynew[5] <= ycoor[5];
		Rnew[5] <= dis[5];
		case({left,right})
		6'b000100: begin
			Xnew[0] <= xcoor[index0];
			Ynew[0] <= ycoor[index0];
			Rnew[0] <= dis  [index0];
		end
		6'b001011: begin
			Xnew[1] <= xcoor[index0];
			Ynew[1] <= ycoor[index0];
			Rnew[1] <= dis  [index0];
		end
		6'b010010: begin
			Xnew[2] <= xcoor[index0];
			Ynew[2] <= ycoor[index0];
			Rnew[2] <= dis  [index0];
		end
		6'b011001: begin
			Xnew[3] <= xcoor[index0];
			Ynew[3] <= ycoor[index0];
			Rnew[3] <= dis  [index0];
		end
		6'b100000: begin
			Xnew[4] <= xcoor[index0];
			Ynew[4] <= ycoor[index0];
			Rnew[4] <= dis  [index0];
		end
		endcase
	end
end

//*************** state inorout ***************

always@(posedge clk or posedge reset)begin
	if(reset)
		inoroutcnt <= 0;
	else if(state == inorout)
		inoroutcnt <= inoroutcnt + 1;
	else 
		inoroutcnt <= 0;
end


reg signed [33:0] area6;
reg signed [30:0] a0, a1, a2, a3, a4, a5, b0, b1;

//***** calculate the area by pipeline *****

always@(posedge clk or posedge reset)begin
	if(reset)begin
		area6 <= 0;
	end
	else if(state == inorout)begin
		a0 <= Xnew[0]*Ynew[1] - Xnew[1]*Ynew[0]; 
		a1 <= Xnew[1]*Ynew[2] - Xnew[2]*Ynew[1]; 
		a2 <= Xnew[2]*Ynew[3] - Xnew[3]*Ynew[2]; 
		a3 <= Xnew[3]*Ynew[4] - Xnew[4]*Ynew[3]; 
		a4 <= Xnew[4]*Ynew[5] - Xnew[5]*Ynew[4]; 
		a5 <= Xnew[5]*Ynew[0] - Xnew[0]*Ynew[5];
		
		b0 <= a0 + a1 + a2;
		b1 <= a3 + a4 + a5;
		
		area6 <=(-1)*(b0+b1)/2; 
	end
end

//****** distance between 2 point *****

wire [15:0] dis2p;
wire [31:0] dissquare;


assign dissquare = (inoroutcnt==5)?((Xnew[5] - Xnew[0])**2 + (Ynew[5] - Ynew[0])**2):
				   (Xnew[inoroutcnt] - Xnew[inoroutcnt+1])**2 + (Ynew[inoroutcnt] - Ynew[inoroutcnt+1])**2;


sqrt sq0(
	.aclr   (reset),
	.clk    (clk),
	.radical(dissquare),
	.q      (dis2p)
);
wire heronen; 
wire [20:0] S;
wire [3:0] heroncnt;
wire [15:0] area30,area31;
wire [31:0] area3;
wire [31:0] area3dou0;
wire [31:0] area3dou1;
reg  [31:0] area3all;


assign heronen = (inoroutcnt>=1)?1:0;
assign heroncnt = inoroutcnt - 1;
assign S = (heroncnt==5)?((dis2p + Rnew[heroncnt] + Rnew[0])/2):
			              (dis2p + Rnew[heroncnt] + Rnew[heroncnt+1])/2;
						  
assign area3dou0 = S*(S-dis2p);
assign area3dou1 = (heroncnt==5)?((S-Rnew[heroncnt])*(S-Rnew[0])):
								  ((S-Rnew[heroncnt])*(S-Rnew[heroncnt+1]));

sqrt sq1(
	.aclr   (reset),
	.clk    (clk),
	.radical(area3dou0),
	.q      (area30)
);

sqrt sq2(
	.aclr   (reset),
	.clk    (clk),
	.radical(area3dou1),
	.q      (area31)
);

assign area3 = area30*area31;

always@(posedge clk or posedge reset)begin
	if(reset)begin
		area3all <= 0;
	end
	else if(inoroutcnt>=2 && state == inorout)begin
		area3all <= area3all + area3;
	end
	else if(state==save)
		area3all <= 0;
end

assign valid = (inoroutcnt == 8)?1:0;
assign is_inside = (area3all>area6)? 0:1;

endmodule

