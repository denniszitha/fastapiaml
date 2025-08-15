import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Dialog, Transition } from '@headlessui/react';
import {
  HomeIcon,
  ChartBarIcon,
  ExclamationTriangleIcon,
  UserGroupIcon,
  EyeIcon,
  ShieldCheckIcon,
  AdjustmentsHorizontalIcon,
  DocumentChartBarIcon,
  Cog6ToothIcon,
  XMarkIcon,
  BanknotesIcon,
  ChartPieIcon,
  BellAlertIcon,
  ClipboardDocumentCheckIcon,
} from '@heroicons/react/24/outline';

const navigation = [
  { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
  { name: 'Transaction Monitoring', href: '/monitoring', icon: ChartBarIcon },
  { name: 'Suspicious Cases', href: '/suspicious-cases', icon: ExclamationTriangleIcon, badge: 'new' },
  { name: 'Customer Profiles', href: '/customer-profiles', icon: UserGroupIcon },
  { name: 'Watchlist', href: '/watchlist', icon: EyeIcon },
  { name: 'Exemptions', href: '/exemptions', icon: ShieldCheckIcon },
  { name: 'Transaction Limits', href: '/limits', icon: AdjustmentsHorizontalIcon },
  { name: 'Reports', href: '/reports', icon: DocumentChartBarIcon },
  { name: 'Settings', href: '/settings', icon: Cog6ToothIcon },
];

const quickActions = [
  { name: 'Review Alerts', icon: BellAlertIcon, count: 12 },
  { name: 'Pending STRs', icon: ClipboardDocumentCheckIcon, count: 3 },
  { name: 'Risk Analysis', icon: ChartPieIcon },
  { name: 'Daily Summary', icon: BanknotesIcon },
];

function classNames(...classes) {
  return classes.filter(Boolean).join(' ');
}

export default function Sidebar({ sidebarOpen, setSidebarOpen }) {
  const location = useLocation();

  return (
    <>
      {/* Mobile sidebar */}
      <Transition.Root show={sidebarOpen} as={React.Fragment}>
        <Dialog as="div" className="relative z-50 lg:hidden" onClose={setSidebarOpen}>
          <Transition.Child
            as={React.Fragment}
            enter="transition-opacity ease-linear duration-300"
            enterFrom="opacity-0"
            enterTo="opacity-100"
            leave="transition-opacity ease-linear duration-300"
            leaveFrom="opacity-100"
            leaveTo="opacity-0"
          >
            <div className="fixed inset-0 bg-gray-900/80" />
          </Transition.Child>

          <div className="fixed inset-0 flex">
            <Transition.Child
              as={React.Fragment}
              enter="transition ease-in-out duration-300 transform"
              enterFrom="-translate-x-full"
              enterTo="translate-x-0"
              leave="transition ease-in-out duration-300 transform"
              leaveFrom="translate-x-0"
              leaveTo="-translate-x-full"
            >
              <Dialog.Panel className="relative mr-16 flex w-full max-w-xs flex-1">
                <Transition.Child
                  as={React.Fragment}
                  enter="ease-in-out duration-300"
                  enterFrom="opacity-0"
                  enterTo="opacity-100"
                  leave="ease-in-out duration-300"
                  leaveFrom="opacity-100"
                  leaveTo="opacity-0"
                >
                  <div className="absolute left-full top-0 flex w-16 justify-center pt-5">
                    <button type="button" className="-m-2.5 p-2.5" onClick={() => setSidebarOpen(false)}>
                      <span className="sr-only">Close sidebar</span>
                      <XMarkIcon className="h-6 w-6 text-white" aria-hidden="true" />
                    </button>
                  </div>
                </Transition.Child>
                <SidebarContent location={location} />
              </Dialog.Panel>
            </Transition.Child>
          </div>
        </Dialog>
      </Transition.Root>

      {/* Static sidebar for desktop */}
      <div className="hidden lg:fixed lg:inset-y-0 lg:z-50 lg:flex lg:w-64 lg:flex-col">
        <SidebarContent location={location} />
      </div>
    </>
  );
}

function SidebarContent({ location }) {
  return (
    <div className="flex grow flex-col gap-y-5 overflow-y-auto bg-gray-900 px-6 pb-4">
      {/* Logo */}
      <div className="flex h-16 shrink-0 items-center">
        <div className="flex items-center space-x-2">
          <div className="w-8 h-8 bg-primary-500 rounded-lg flex items-center justify-center">
            <span className="text-white font-bold text-lg">A</span>
          </div>
          <span className="text-white font-semibold text-lg">AML Monitor</span>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex flex-1 flex-col">
        <ul role="list" className="flex flex-1 flex-col gap-y-7">
          <li>
            <div className="text-xs font-semibold leading-6 text-gray-400">Main Menu</div>
            <ul role="list" className="-mx-2 mt-2 space-y-1">
              {navigation.map((item) => (
                <li key={item.name}>
                  <Link
                    to={item.href}
                    className={classNames(
                      location.pathname === item.href
                        ? 'bg-gray-800 text-white'
                        : 'text-gray-400 hover:text-white hover:bg-gray-800',
                      'group flex gap-x-3 rounded-md p-2 text-sm leading-6 font-semibold'
                    )}
                  >
                    <item.icon className="h-6 w-6 shrink-0" aria-hidden="true" />
                    {item.name}
                    {item.badge && (
                      <span className="ml-auto inline-flex items-center rounded-full bg-danger-600 px-2 py-0.5 text-xs font-medium text-white">
                        {item.badge}
                      </span>
                    )}
                  </Link>
                </li>
              ))}
            </ul>
          </li>

          {/* Quick Actions */}
          <li>
            <div className="text-xs font-semibold leading-6 text-gray-400">Quick Actions</div>
            <ul role="list" className="-mx-2 mt-2 space-y-1">
              {quickActions.map((action) => (
                <li key={action.name}>
                  <button className="text-gray-400 hover:text-white hover:bg-gray-800 group flex gap-x-3 rounded-md p-2 text-sm leading-6 font-semibold w-full">
                    <action.icon className="h-5 w-5 shrink-0" aria-hidden="true" />
                    <span className="truncate">{action.name}</span>
                    {action.count && (
                      <span className="ml-auto inline-flex items-center rounded-full bg-gray-700 px-2 py-0.5 text-xs font-medium text-gray-300">
                        {action.count}
                      </span>
                    )}
                  </button>
                </li>
              ))}
            </ul>
          </li>

          {/* System Status */}
          <li className="mt-auto">
            <div className="rounded-lg bg-gray-800 p-4">
              <div className="flex items-center gap-x-3">
                <div className="flex h-2 w-2">
                  <span className="animate-ping absolute inline-flex h-2 w-2 rounded-full bg-success-400 opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-success-500"></span>
                </div>
                <div className="text-sm">
                  <p className="text-gray-400">System Status</p>
                  <p className="text-white font-medium">All Systems Operational</p>
                </div>
              </div>
            </div>
          </li>
        </ul>
      </nav>
    </div>
  );
}