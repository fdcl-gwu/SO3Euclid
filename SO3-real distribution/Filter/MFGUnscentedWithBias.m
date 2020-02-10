function [ R, MFG, stepT ] = MFGUnscentedWithBias( gyro, RMea, parameters )

filePath = mfilename('fullpath');
pathCell = regexp(path, pathsep, 'split');
if ~any(strcmp(pathCell,getAbsPath('..\..\rotation3d',filePath)))
    addpath(getAbsPath('..\..\rotation3d',filePath));
end
if ~any(strcmp(pathCell,getAbsPath('..\Matrix-Fisher-Distribution',filePath)))
    addpath(getAbsPath('..\Matrix-Fisher-Distribution',filePath));
end
if ~any(strcmp(pathCell,getAbsPath('..\',filePath)))
    addpath(getAbsPath('..\',filePath));
end

N = size(gyro,2);
dt = parameters.dt;

% noise parameters
randomWalk = parameters.randomWalk;
biasInstability = parameters.biasInstability;
if parameters.GaussMea
    SM = Gau2MF(parameters.rotMeaNoise);
else
    SM = eye(3)*parameters.rotMeaNoise;
end

% initialize distribution
Miu = parameters.xInit;
Sigma = eye(3)*parameters.initXNoise^2;
P = zeros(3);
U = parameters.RInit;
V = eye(3);
if parameters.GaussMea
    S = Gau2MF(parameters.initRNoise);
else
    S = eye(3)*parameters.initRNoise;
end

% data containers
MFG.Miu = zeros(3,N); MFG.Miu(:,1) = Miu;
MFG.Sigma = zeros(3,3,N); MFG.Sigma(:,:,1) = Sigma;
MFG.P = zeros(3,3,N); MFG.P(:,:,1) = P;
MFG.U = zeros(3,3,N); MFG.U(:,:,1) = U;
MFG.V = zeros(3,3,N); MFG.V(:,:,1) = V;
MFG.S = zeros(3,N); MFG.S(:,1) = diag(S);
R = zeros(3,3,N); R(:,:,1) = U*V';
stepT = zeros(N-1,1);

% filter iteration
for n = 2:N
    tic;
    
    % unscented transform for last step
    [xl,Rl,wl] = MFGGetSigmaPoints(Miu,Sigma,P,U,S,V);
    [xav,wav] = GGetSigmaPoints([0;0;0],eye(3)*randomWalk^2/dt);
    [xb,wb] = GGetSigmaPoints([0;0;0],eye(3)*biasInstability^2/dt);
    
    % propagate sigma points
    xp = zeros(3,13*7*7);
    Rp = zeros(3,3,13*7*7);
    wp = zeros(1,13*7*7);
    for i = 1:13
        for j = 1:7
            for k = 1:7
                ind = 7*7*(i-1)+7*(j-1)+k;
                Rp(:,:,ind) = Rl(:,:,i)*expRot(((gyro(:,n-1)+gyro(:,n))...
                    /2-xl(:,i)-xav(:,j))*dt);
                xp(:,ind) = xl(:,i)+xb(:,k)*dt;
                wp(ind) = wl(i)*wav(j)*wb(k);
            end
        end
    end
    
    % recover prior distribution
    [Miu,Sigma,P,U,S,V] = MFGMLEAppro(xp,Rp,wp);
    
    % update
    if rem(n,5)==0
        [Miu,Sigma,P,U,S,V] = MFGMulMF(Miu,Sigma,P,U,S,V,RMea(:,:,n)*SM);
    end
    
    % record results
    MFG.Miu(:,n) = Miu;
    MFG.Sigma(:,:,n) = Sigma;
    MFG.P(:,:,n) = P;
    MFG.U(:,:,n) = U;
    MFG.V(:,:,n) = V;
    MFG.S(:,n) = diag(S);
    R(:,:,n) = U*V';
    
    stepT(n-1) = toc;
end

if ~any(strcmp(pathCell,getAbsPath('..\..\rotation3d',filePath)))
    rmpath(getAbsPath('..\..\rotation3d',filePath));
end
if ~any(strcmp(pathCell,getAbsPath('..\Matrix-Fisher-Distribution',filePath)))
    addpath(getAbsPath('..\Matrix-Fisher-Distribution',filePath));
end
if ~any(strcmp(pathCell,getAbsPath('..\',filePath)))
    rmpath(getAbsPath('..\',filePath));
end

end


function [ S ] = Gau2MF( sigma )

N = 100000;
v = sigma*randn(3,N);

R = expRot(v);
ER = mean(R,3);
[~,D,~] = psvd(ER);

S = pdf_MF_M2S(diag(D));
S = eye(3)*mean(S);

end

