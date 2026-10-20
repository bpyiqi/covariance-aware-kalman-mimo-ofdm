function Preal = ucComplexCovToRealState(Ph,Ppseudo)
% Exact inverse mapping for the documented complex covariance pair.
if nargin<2, error('Ppseudo is required; it must not be assumed zero.'); end
PRR=real(Ph+Ppseudo)/2; PII=real(Ph-Ppseudo)/2;
PIR=imag(Ph+Ppseudo)/2; PRI=imag(Ppseudo-Ph)/2;
Preal=[PRR PRI; PIR PII];
Preal=(Preal+Preal')/2;
end
