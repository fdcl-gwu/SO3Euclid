function [ Miu, Sigma, P, U, S, V ] = MFGMLEAppro( x, R, w, defQS, s0, approx )
% let x be N-by-Ns, R be 3-by-3-by-Ns

N = size(x,1);
Ns = size(R,3);

if ~exist('w','var') || isempty(w)
    w = ones(1,Ns)/Ns;
end

if ~exist('approx','var') || isempty(approx)
    approx = false;
end

% empirical moments
Ex = sum(x.*w,2);
ER = sum(R.*reshape(w,1,1,[]),3);

covxx = zeros(N,N);
for ns = 1:Ns
    covxx = covxx+(x(:,ns)-Ex)*(x(:,ns)-Ex)'*w(ns);
end

% Matrix Fisher part
[U,D,V] = psvd(ER);
if ~exist('s0','var') || isempty(s0)
    S = diag(pdf_MF_M2S(diag(D)));
else
    S = diag(pdf_MF_M2S(diag(D),s0));
end

% vR
Q = mulRot(mulRot(U',R,0),V,0);
if defQS
    vR = vee(mulRot(Q,S,0)-mulRot(S,permute(Q,[2,1,3]),0));
else
    vR = vee(mulRot(S,Q,0)-mulRot(permute(Q,[2,1,3]),S,0));
end

% other empirical moments
EvR = sum(vR.*w,2);

covxvR = zeros(N,3);
covvRvR = zeros(3,3);
for ns = 1:Ns
    covxvR = covxvR+(x(:,ns)-Ex)*(vR(:,ns)-EvR)'*w(ns);
    covvRvR = covvRvR+(vR(:,ns)-EvR)*(vR(:,ns)-EvR)'*w(ns);
end

% correlation part
P = covxvR*covvRvR^-1;

if approx
    if S(2,2)+S(3,3) < 1
        P(:,1) = 0;
        covxvR(:,1) = 0;
    end
end

% Gaussian part
SigmaTilde2Inv = diag([S(2,2)+S(3,3),S(1,1)+S(3,3),S(1,1)+S(2,2)]);
Miu = Ex-P*EvR;
Sigma = covxx-covxvR*covvRvR^-1*covxvR'+...
    P*SigmaTilde2Inv*P';

end

