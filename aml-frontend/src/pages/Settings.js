import React, { useState } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  CogIcon,
  BellIcon,
  ShieldCheckIcon,
  ServerIcon,
  UserGroupIcon,
  KeyIcon,
  GlobeAltIcon,
  DocumentTextIcon,
  PaintBrushIcon,
  CpuChipIcon,
  CheckIcon,
  XMarkIcon,
  ArrowPathIcon,
  InformationCircleIcon,
  ExclamationTriangleIcon,
} from '@heroicons/react/24/outline';

const settingsSections = [
  { id: 'general', name: 'General', icon: CogIcon },
  { id: 'notifications', name: 'Notifications', icon: BellIcon },
  { id: 'security', name: 'Security', icon: ShieldCheckIcon },
  { id: 'api', name: 'API Configuration', icon: ServerIcon },
  { id: 'users', name: 'User Management', icon: UserGroupIcon },
  { id: 'appearance', name: 'Appearance', icon: PaintBrushIcon },
  { id: 'system', name: 'System', icon: CpuChipIcon },
];

export default function Settings() {
  const [activeSection, setActiveSection] = useState('general');
  const [hasChanges, setHasChanges] = useState(false);
  
  // Settings state
  const [settings, setSettings] = useState({
    general: {
      organizationName: 'NATSAVE Bank',
      timezone: 'Africa/Harare',
      currency: 'USD',
      language: 'en',
      dateFormat: 'MM/DD/YYYY',
      autoSave: true,
    },
    notifications: {
      emailAlerts: true,
      smsAlerts: false,
      pushNotifications: true,
      dailyDigest: true,
      highRiskAlerts: true,
      systemUpdates: false,
      alertThreshold: 70,
    },
    security: {
      twoFactorAuth: true,
      sessionTimeout: 30,
      passwordExpiry: 90,
      minPasswordLength: 12,
      requireSpecialChars: true,
      requireNumbers: true,
      ipWhitelisting: false,
      auditLogging: true,
    },
    api: {
      webhookUrl: 'https://api.natsave.com/webhook',
      apiKey: '**********************',
      rateLimit: 1000,
      timeout: 30,
      retryAttempts: 3,
      environment: 'production',
    },
    appearance: {
      theme: 'light',
      primaryColor: '#3b82f6',
      sidebarPosition: 'left',
      compactMode: false,
      showAnimations: true,
    },
    system: {
      debugMode: false,
      maintenanceMode: false,
      backupFrequency: 'daily',
      dataRetention: 365,
      maxFileSize: 10,
      enableMetrics: true,
    },
  });

  const [tempSettings, setTempSettings] = useState(settings);

  const updateSetting = (section, key, value) => {
    setTempSettings(prev => ({
      ...prev,
      [section]: {
        ...prev[section],
        [key]: value,
      },
    }));
    setHasChanges(true);
  };

  const handleSave = () => {
    setSettings(tempSettings);
    setHasChanges(false);
    toast.success('Settings saved successfully');
  };

  const handleCancel = () => {
    setTempSettings(settings);
    setHasChanges(false);
  };

  const handleReset = () => {
    toast.success('Settings reset to defaults');
  };

  const renderGeneralSettings = () => (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-medium text-gray-900 mb-4">General Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="label">Organization Name</label>
            <input
              type="text"
              value={tempSettings.general.organizationName}
              onChange={(e) => updateSetting('general', 'organizationName', e.target.value)}
              className="input"
            />
          </div>
          <div>
            <label className="label">Timezone</label>
            <select
              value={tempSettings.general.timezone}
              onChange={(e) => updateSetting('general', 'timezone', e.target.value)}
              className="input"
            >
              <option value="Africa/Harare">Africa/Harare (CAT)</option>
              <option value="UTC">UTC</option>
              <option value="America/New_York">America/New York (EST)</option>
              <option value="Europe/London">Europe/London (GMT)</option>
            </select>
          </div>
          <div>
            <label className="label">Default Currency</label>
            <select
              value={tempSettings.general.currency}
              onChange={(e) => updateSetting('general', 'currency', e.target.value)}
              className="input"
            >
              <option value="USD">USD - US Dollar</option>
              <option value="EUR">EUR - Euro</option>
              <option value="GBP">GBP - British Pound</option>
              <option value="ZWL">ZWL - Zimbabwe Dollar</option>
            </select>
          </div>
          <div>
            <label className="label">Language</label>
            <select
              value={tempSettings.general.language}
              onChange={(e) => updateSetting('general', 'language', e.target.value)}
              className="input"
            >
              <option value="en">English</option>
              <option value="es">Spanish</option>
              <option value="fr">French</option>
              <option value="pt">Portuguese</option>
            </select>
          </div>
          <div>
            <label className="label">Date Format</label>
            <select
              value={tempSettings.general.dateFormat}
              onChange={(e) => updateSetting('general', 'dateFormat', e.target.value)}
              className="input"
            >
              <option value="MM/DD/YYYY">MM/DD/YYYY</option>
              <option value="DD/MM/YYYY">DD/MM/YYYY</option>
              <option value="YYYY-MM-DD">YYYY-MM-DD</option>
            </select>
          </div>
          <div className="flex items-center justify-between">
            <label className="label mb-0">Auto-save Changes</label>
            <button
              onClick={() => updateSetting('general', 'autoSave', !tempSettings.general.autoSave)}
              className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out ${
                tempSettings.general.autoSave ? 'bg-primary-600' : 'bg-gray-200'
              }`}
            >
              <span
                className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                  tempSettings.general.autoSave ? 'translate-x-5' : 'translate-x-0'
                }`}
              />
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  const renderNotificationSettings = () => (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-medium text-gray-900 mb-4">Notification Preferences</h3>
        <div className="space-y-4">
          {[
            { key: 'emailAlerts', label: 'Email Alerts', desc: 'Receive alerts via email' },
            { key: 'smsAlerts', label: 'SMS Alerts', desc: 'Receive alerts via SMS' },
            { key: 'pushNotifications', label: 'Push Notifications', desc: 'Browser push notifications' },
            { key: 'dailyDigest', label: 'Daily Digest', desc: 'Summary of daily activities' },
            { key: 'highRiskAlerts', label: 'High Risk Alerts', desc: 'Immediate alerts for high-risk transactions' },
            { key: 'systemUpdates', label: 'System Updates', desc: 'Notifications about system maintenance' },
          ].map(({ key, label, desc }) => (
            <div key={key} className="flex items-center justify-between py-3 border-b border-gray-100">
              <div>
                <p className="text-sm font-medium text-gray-900">{label}</p>
                <p className="text-sm text-gray-500">{desc}</p>
              </div>
              <button
                onClick={() => updateSetting('notifications', key, !tempSettings.notifications[key])}
                className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out ${
                  tempSettings.notifications[key] ? 'bg-primary-600' : 'bg-gray-200'
                }`}
              >
                <span
                  className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                    tempSettings.notifications[key] ? 'translate-x-5' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>
          ))}
          <div>
            <label className="label">Alert Threshold (Risk Score)</label>
            <div className="flex items-center space-x-3">
              <input
                type="range"
                min="0"
                max="100"
                value={tempSettings.notifications.alertThreshold}
                onChange={(e) => updateSetting('notifications', 'alertThreshold', parseInt(e.target.value))}
                className="flex-1"
              />
              <span className="text-sm font-medium text-gray-900 w-12">
                {tempSettings.notifications.alertThreshold}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );

  const renderSecuritySettings = () => (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-medium text-gray-900 mb-4">Security Settings</h3>
        <div className="space-y-4">
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <div className="flex">
              <ExclamationTriangleIcon className="h-5 w-5 text-yellow-400 mt-0.5" />
              <div className="ml-3">
                <h3 className="text-sm font-medium text-yellow-800">Important</h3>
                <p className="mt-1 text-sm text-yellow-700">
                  Changes to security settings will affect all users in your organization.
                </p>
              </div>
            </div>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-900">Two-Factor Authentication</p>
                <p className="text-sm text-gray-500">Require 2FA for all users</p>
              </div>
              <button
                onClick={() => updateSetting('security', 'twoFactorAuth', !tempSettings.security.twoFactorAuth)}
                className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out ${
                  tempSettings.security.twoFactorAuth ? 'bg-primary-600' : 'bg-gray-200'
                }`}
              >
                <span
                  className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                    tempSettings.security.twoFactorAuth ? 'translate-x-5' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>
            
            <div>
              <label className="label">Session Timeout (minutes)</label>
              <input
                type="number"
                value={tempSettings.security.sessionTimeout}
                onChange={(e) => updateSetting('security', 'sessionTimeout', parseInt(e.target.value))}
                className="input"
              />
            </div>
            
            <div>
              <label className="label">Password Expiry (days)</label>
              <input
                type="number"
                value={tempSettings.security.passwordExpiry}
                onChange={(e) => updateSetting('security', 'passwordExpiry', parseInt(e.target.value))}
                className="input"
              />
            </div>
            
            <div>
              <label className="label">Minimum Password Length</label>
              <input
                type="number"
                value={tempSettings.security.minPasswordLength}
                onChange={(e) => updateSetting('security', 'minPasswordLength', parseInt(e.target.value))}
                className="input"
              />
            </div>
          </div>
          
          <div className="space-y-3">
            {[
              { key: 'requireSpecialChars', label: 'Require Special Characters' },
              { key: 'requireNumbers', label: 'Require Numbers' },
              { key: 'ipWhitelisting', label: 'IP Whitelisting' },
              { key: 'auditLogging', label: 'Audit Logging' },
            ].map(({ key, label }) => (
              <div key={key} className="flex items-center justify-between py-2">
                <label className="text-sm font-medium text-gray-900">{label}</label>
                <button
                  onClick={() => updateSetting('security', key, !tempSettings.security[key])}
                  className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out ${
                    tempSettings.security[key] ? 'bg-primary-600' : 'bg-gray-200'
                  }`}
                >
                  <span
                    className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                      tempSettings.security[key] ? 'translate-x-5' : 'translate-x-0'
                    }`}
                  />
                </button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );

  const renderApiSettings = () => (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-medium text-gray-900 mb-4">API Configuration</h3>
        <div className="space-y-4">
          <div>
            <label className="label">Webhook URL</label>
            <input
              type="url"
              value={tempSettings.api.webhookUrl}
              onChange={(e) => updateSetting('api', 'webhookUrl', e.target.value)}
              className="input"
            />
          </div>
          
          <div>
            <label className="label">API Key</label>
            <div className="flex space-x-2">
              <input
                type="password"
                value={tempSettings.api.apiKey}
                onChange={(e) => updateSetting('api', 'apiKey', e.target.value)}
                className="input flex-1"
              />
              <button className="btn btn-secondary">
                <KeyIcon className="h-4 w-4 mr-2" />
                Regenerate
              </button>
            </div>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="label">Rate Limit (req/hour)</label>
              <input
                type="number"
                value={tempSettings.api.rateLimit}
                onChange={(e) => updateSetting('api', 'rateLimit', parseInt(e.target.value))}
                className="input"
              />
            </div>
            
            <div>
              <label className="label">Timeout (seconds)</label>
              <input
                type="number"
                value={tempSettings.api.timeout}
                onChange={(e) => updateSetting('api', 'timeout', parseInt(e.target.value))}
                className="input"
              />
            </div>
            
            <div>
              <label className="label">Retry Attempts</label>
              <input
                type="number"
                value={tempSettings.api.retryAttempts}
                onChange={(e) => updateSetting('api', 'retryAttempts', parseInt(e.target.value))}
                className="input"
              />
            </div>
          </div>
          
          <div>
            <label className="label">Environment</label>
            <select
              value={tempSettings.api.environment}
              onChange={(e) => updateSetting('api', 'environment', e.target.value)}
              className="input"
            >
              <option value="development">Development</option>
              <option value="staging">Staging</option>
              <option value="production">Production</option>
            </select>
          </div>
        </div>
      </div>
    </div>
  );

  const renderContent = () => {
    switch (activeSection) {
      case 'general':
        return renderGeneralSettings();
      case 'notifications':
        return renderNotificationSettings();
      case 'security':
        return renderSecuritySettings();
      case 'api':
        return renderApiSettings();
      case 'users':
        return (
          <div className="text-center py-12">
            <UserGroupIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900">User Management</h3>
            <p className="text-sm text-gray-500 mt-2">User management interface coming soon</p>
          </div>
        );
      case 'appearance':
        return (
          <div className="text-center py-12">
            <PaintBrushIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900">Appearance Settings</h3>
            <p className="text-sm text-gray-500 mt-2">Theme customization coming soon</p>
          </div>
        );
      case 'system':
        return (
          <div className="text-center py-12">
            <CpuChipIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900">System Settings</h3>
            <p className="text-sm text-gray-500 mt-2">System configuration coming soon</p>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Settings</h1>
          <p className="mt-1 text-sm text-gray-500">
            Manage system configuration and preferences
          </p>
        </div>
      </div>

      <div className="flex gap-6">
        {/* Sidebar */}
        <div className="w-64 flex-shrink-0">
          <nav className="space-y-1">
            {settingsSections.map((section) => {
              const Icon = section.icon;
              return (
                <button
                  key={section.id}
                  onClick={() => setActiveSection(section.id)}
                  className={`w-full flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors ${
                    activeSection === section.id
                      ? 'bg-primary-100 text-primary-900'
                      : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                  }`}
                >
                  <Icon className="h-5 w-5 mr-3" />
                  {section.name}
                </button>
              );
            })}
          </nav>
        </div>

        {/* Content */}
        <div className="flex-1">
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            {renderContent()}
            
            {/* Save Actions */}
            {hasChanges && (
              <div className="mt-6 pt-6 border-t border-gray-200 flex justify-end space-x-3">
                <button
                  onClick={handleCancel}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSave}
                  className="btn btn-primary"
                >
                  <CheckIcon className="h-4 w-4 mr-2" />
                  Save Changes
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}