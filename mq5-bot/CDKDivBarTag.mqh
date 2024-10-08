//+------------------------------------------------------------------+
//|                                                 CDKDivBarTag.mqh |
//|                                                  Denis Kislitsyn |
//|                                               http:/kislitsyn.me |
//+------------------------------------------------------------------+

#include "Include\DKStdLib\Common\CDKBarTag.mqh" 

class CDKDivBarTag : public CDKBarTag  {
protected:
  double                _Value2;
public:
  void                  CDKDivBarTag::CDKDivBarTag(void);
  
  void                  CDKDivBarTag::SetValue2(const double aValue);
  double                CDKDivBarTag::GetValue2();
};

void CDKDivBarTag::CDKDivBarTag(void) {
  _Sym = "";
  _TF = PERIOD_CURRENT;
  _Index = -1;
  _Time = 0;
  _Value = 0;
  _Value2 = 0.0;
}

void CDKDivBarTag::SetValue2(const double aValue) {
  _Value2 = aValue;
}

double CDKDivBarTag::GetValue2() {
  return _Value2;
}