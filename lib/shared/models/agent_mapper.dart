import 'package:bingwa_pro/shared/models/auth_model.dart';
import 'package:bingwa_pro/shared/models/agent_model.dart';

class AgentMapper {
  // Convert auth AgentProfile to detailed AgentDetailedProfile
  static AgentDetailedProfile toDetailedProfile(
    AgentProfile authProfile, {
    AgentStats? stats,
    AgentSettings? settings,
    List<AgentDocument>? documents,
    AgentTier? tier,
  }) {
    // Map AgentAuthStatus to AgentStatus
    final status = _mapAuthStatusToAgentStatus(authProfile.status);
    
    return AgentDetailedProfile(
      id: authProfile.id,
      fullName: authProfile.fullName,
      phoneNumber: authProfile.phoneNumber,
      email: authProfile.email,
      status: status,
      tokenBalance: authProfile.tokenBalance,
      registeredAt: authProfile.registeredAt,
      lastLoginAt: authProfile.lastLoginAt,
      nationalId: authProfile.nationalId,
      agentCode: authProfile.agentCode,
      businessName: authProfile.businessName,
      location: authProfile.location,
      totalCommission: authProfile.totalCommission,
      totalTransactions: authProfile.totalTransactions,
      successRate: authProfile.successRate,
      stats: stats,
      settings: settings,
      documents: documents,
      tier: tier,
      metadata: authProfile.metadata,
    );
  }
  
  static AgentStatus _mapAuthStatusToAgentStatus(AgentAuthStatus authStatus) {
    switch (authStatus) {
      case AgentAuthStatus.pending:
        return AgentStatus.pending;
      case AgentAuthStatus.active:
        return AgentStatus.active;
      case AgentAuthStatus.suspended:
        return AgentStatus.suspended;
      case AgentAuthStatus.terminated:
        return AgentStatus.terminated;
      case AgentAuthStatus.pendingVerification:
        return AgentStatus.pendingVerification;
    }
  }
  
  // Convert detailed profile back to auth profile if needed
  static AgentProfile toAuthProfile(AgentDetailedProfile detailedProfile) {
    return AgentProfile(
      id: detailedProfile.id,
      fullName: detailedProfile.fullName,
      phoneNumber: detailedProfile.phoneNumber,
      email: detailedProfile.email,
      status: _mapAgentStatusToAuthStatus(detailedProfile.status),
      tokenBalance: detailedProfile.tokenBalance,
      registeredAt: detailedProfile.registeredAt,
      lastLoginAt: detailedProfile.lastLoginAt,
      nationalId: detailedProfile.nationalId,
      agentCode: detailedProfile.agentCode,
      businessName: detailedProfile.businessName,
      location: detailedProfile.location,
      totalCommission: detailedProfile.totalCommission,
      totalTransactions: detailedProfile.totalTransactions,
      successRate: detailedProfile.successRate,
      metadata: detailedProfile.metadata,
    );
  }
  
  static AgentAuthStatus _mapAgentStatusToAuthStatus(AgentStatus status) {
    switch (status) {
      case AgentStatus.pending:
        return AgentAuthStatus.pending;
      case AgentStatus.active:
        return AgentAuthStatus.active;
      case AgentStatus.suspended:
        return AgentAuthStatus.suspended;
      case AgentStatus.terminated:
        return AgentAuthStatus.terminated;
      case AgentStatus.pendingVerification:
        return AgentAuthStatus.pendingVerification;
    }
  }
}