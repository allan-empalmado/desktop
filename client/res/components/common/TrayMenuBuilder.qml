// Copyright (c) 2019 London Trust Media Incorporated
//
// This file is part of the Private Internet Access Desktop Client.
//
// The Private Internet Access Desktop Client is free software: you can
// redistribute it and/or modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation, either version 3 of
// the License, or (at your option) any later version.
//
// The Private Internet Access Desktop Client is distributed in the hope that
// it will be useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with the Private Internet Access Desktop Client.  If not, see
// <https://www.gnu.org/licenses/>.

import QtQuick 2.9
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import QtQuick.Window 2.11
import "../client"
import "../daemon"
import "../vpnconnection"
import PIA.NativeHelpers 1.0
import PIA.Clipboard 1.0
import PIA.BrandHelper 1.0

Item {
  // The dashboard controlled by the Show Window and Log In menu items
  property Window dashboard

  // The menu content is built as an array of objects representing each menu
  // item.  By doing this declaratively, we ensure that any data we touch will
  // cause the menu to be rebuilt if it changes.
  //
  // Each object can be:
  // - a separator
  //   - 'separator': true
  // - a menu item
  //   - text: <display text>
  //   - code: <exec code string>
  //   - enabled: <boolean>
  property var menuContent: {
    var content = []

    function addMenuItem(text, code, enabled, icon) {
      content.push({text: text, code: code, enabled: enabled, icon: icon })
    }
    function addSeparator() {
      content.push({separator: true})
    }
    function flag(country) {
      return country ? ":/img/flags/" + country.toLowerCase() + ".png" : undefined
    }

    // On Linux, we can't be sure that the user has any way to 'activate' the
    // tray icon, they might only be able to show its menu.  Include a "Show
    // Window" menu item (even if the dashboard is using the "popup" style)
    var showWindowInMenu = Qt.platform.os === 'linux'

    if(showWindowInMenu) {
      //: Menu command to display the main app window/dashboard.
      addMenuItem(uiTr("Show Window"), 'show-dashboard', true)
    }

    if (Daemon.account.loggedIn) {

      if(connState.snoozeState === connState.snoozeDisconnected) {
        // If a snooze is active, don't show connect/disconnect menu items
          addMenuItem(uiTr("Resume Connection"), 'snooze-resume', true)
      } else {
        //: Menu command to connect to an automatically chosen region.
        var connectAutoStr = uiTr("Connect (Auto)")
        //: Menu command to connect to a specific bookmarked region, with the region name in parentheses.
        var connectServerStr = uiTr("Connect (%1)")

        // Add a connect menu item that connects to the current location.  Include
        // the current location's name.
        if(!Daemon.state.vpnLocations.chosenLocation) {
          addMenuItem(connectAutoStr, 'connect', Daemon.state.connectionState === "Disconnected")
        }
        else {
          addMenuItem(connectServerStr.arg(Daemon.getLocationName(Daemon.state.vpnLocations.chosenLocation)),
                      'loc/' + Daemon.state.vpnLocations.chosenLocation.id, Daemon.state.connectionState === "Disconnected", flag(Daemon.state.vpnLocations.chosenLocation.country))
        }
        //: Menu command to disconnect from the VPN.
        addMenuItem(uiTr("Disconnect"), 'disconnect', Daemon.state.connectionState !== "Disconnected")

        if(connState.canSnooze) {
          content.push({ text: uiTr("Snooze"), code: 'snooze', children: [
                           { text: uiTr("5 Minutes"), code: 'snooze/5' },
                           { text: uiTr("10 Minutes"), code: 'snooze/10' },
                           { text: uiTr("15 Minutes"), code: 'snooze/15' },
                           { text: uiTr("30 Minutes"), code: 'snooze/30' },
                         ]});
        }

        addSeparator()

        var favs = Client.sortedFavorites
        if (Daemon.state.vpnLocations.chosenLocation) {
          // Add a persistent favorite for "auto" unless it's the current region
          addMenuItem(connectAutoStr, "loc/auto", true)
        }
        var chosenLocationId = Daemon.state.vpnLocations.chosenLocation ? Daemon.state.vpnLocations.chosenLocation.id : ''
        for (var i = 0; i < favs.length; i++) {
          var key = favs[i]
          if (key === chosenLocationId) continue
          var name = Client.getFavoriteLocalizedName(key)
          addMenuItem(connectServerStr.arg(name), "loc/" + key, true, flag(Client.countryFromLocation(key)))
        }
        if (Daemon.state.vpnLocations.chosenLocation || favs.length > 0) {
          addSeparator()
        }
        var regions = []
        for (var i = 0; i < Daemon.state.groupedLocations.length; i++) {
          var country = Daemon.state.groupedLocations[i]
          // Note: the Ubuntu 18 tray menu implementation doesn't support multiple
          // nested submenus, so flatten the region list on Linux.
          if (country.locations.length === 1 || Qt.platform.os === 'linux') {
            for (var j = 0; j < country.locations.length; j++) {
              regions.push({
                             text: Daemon.getLocationName(country.locations[j]),
                             code: "loc/" + country.locations[j].id,
                             icon: flag(country.locations[j].country)
                           })
            }
          } else {
            regions.push({
                           text: Daemon.getCountryName(country.locations[0].country),
                           code: 'country/' + country.locations[0].country,
                           icon: flag(country.locations[0].country),
                           children: country.locations.map(function(l) {
                             return { text: Daemon.getLocationName(l), code: "loc/" + l.id, icon: flag(l.country) } }).sort(function(a,b) { return a.text.localeCompare(b.text) })
                         })
          }
        }
        //: Menu label for a submenu containing a list of regions to connect to.
        content.push({ text: uiTr("Connect to"), code: 'locations', children: regions.sort(function(a,b) { return a.text.localeCompare(b.text) }) })
        addSeparator()
      }
    } else if(!showWindowInMenu) {
      // No need for this if Show Window was added - it does the same thing
      //: Menu command to display the main app window where the user can log in.
      addMenuItem(uiTr("Log In"), 'show-dashboard', true)
      addSeparator()
    }

    if(ClientNotifications.updateAvailable.showInMenus) {
      addMenuItem(ClientNotifications.updateAvailable.menuText,
                  'update', ClientNotifications.updateAvailable.enableInMenus)
      addSeparator()
    }

    //: Menu command to open the settings dialog.
    addMenuItem(uiTr("Settings..."), 'show-settings', true)
    //: Menu label for a submenu containing help and support items.
    content.push({ text: Messages.helpLabel, code: 'help', children: [
                     //: Menu command to enable or disable debug logging, which stores additional information that help developers identify and debug problems.
                     { text: uiTr("Enable Debug Logging"), code: 'toggle-debug-logging', checked: Daemon.settings.debugLogging !== null },
                     //: Menu command to open a dialog that lets the user submit collected debug logs to developers for debugging.
                     { text: uiTr("Submit Debug Logs..."), code: 'submit-debug-logs' },
                     { separator: true },
                     //: Menu command to display a list of changes introduced in each version of the application.
                     { text: uiTr("Changelog"), code: 'show-changelog' },
                     { separator: true },
                     //: Menu command to open the support portal website in the user's browser.
                     { text: uiTr("Support Portal"), code: 'open-support-portal' },
                     //: Menu command to open the company blog website in the user's browser.
                     { text: uiTr("Blog"), code: 'open-blog' },
                   ] })
    addSeparator()

    // Only enable the menuitem if we're connected AND the externalVpnIP is set
    if (Daemon.state.connectionState === "Connected" && Daemon.state.externalVpnIp) {
      //: Menu command to copy the user's current public IP address to the clipboard.
      //: The %1 placeholder contains the IP address, e.g. "10.0.23.45".
      addMenuItem(uiTr("Copy Public IP (%1)").arg(Daemon.state.externalVpnIp), 'copy-public-ip', true)
    }
    else {
      //: Menu command to copy the user's current public IP address to the clipboard.
      //: This variation should match the "Copy Public IP (%1)" string, but omits the
      //: parenthesis and is shown grayed out, used when disconnected.
      addMenuItem(uiTr("Copy Public IP"), 'copy-public-ip', false)
    }

    if (Daemon.settings.portForward) {
      if (Daemon.state.forwardedPort > 0) {
        //: Menu command to copy the port number that is currently being forwarded
        //: (from the VPN to the user's computer) to the clipboard. The %1 placeholder
        //: contains the port number, e.g. "47650".
        addMenuItem(uiTr("Copy Forwarded Port (%1)").arg(Daemon.state.forwardedPort) , 'copy-forwarded-port', true)
      }
      else {
        //: Menu command to copy the port number that is currently being forwarded
        //: (from the VPN to the user's computer) to the clipboard. This variation
        //: should match the "Copy Forwarded Port (%1)" string, but omits the
        //: parenthesis and is shown grayed out, used when port forwarding is not
        //: available.
        addMenuItem(uiTr("Copy Forwarded Port") , 'copy-forwarded-port', false)
      }
    }
    addSeparator()

    //: Menu command to quit the application.
    addMenuItem(uiTr("Quit"), 'quit', true)

    return content
  }

  // Build the actual tray menu imperatively from the menu content
  onMenuContentChanged: {
    TrayIcon.setMenuItems(menuContent)
  }

  function handleSelection(code) {
    if(code.startsWith("loc/")) {
      var region = code.slice(4);
      VpnConnection.connectLocation(Client.realLocation(region));
      return;
    }
    if(code.startsWith("snooze/")) {
      var snoozeAmount = parseInt(code.slice(7)) * 60;
      if(connState.canSnooze && !isNaN(snoozeAmount)) {
        Daemon.startSnooze(snoozeAmount)
      }

      return;
    }

    switch (code) {
    case 'connect':
      if (Daemon.state.connectionState === "Disconnected") {
        VpnConnection.connectCurrentLocation()
      }
      break;
    case 'disconnect':
      if (Daemon.state.connectionState !== "Disconnected") {
        Daemon.disconnectVPN();
      }
      break;
    case 'update':
      ClientNotifications.updateAvailable.menuSelected()
      break
    case 'snooze-resume':
      if(connState.canResumeFromSnooze) {
        Daemon.stopSnooze();
      }
      break;
    case 'quit':
      console.info("Quit from tray menu")
      Qt.quit()
      break
    case 'show-dashboard':
      dashboard.showFromTrayMenu()
      break
    case 'show-settings':
      wSettings.showSettings()
      break
    case 'show-changelog':
      wChangeLog.show()
      wChangeLog.raise()
      wChangeLog.requestActivate()
      break
    case 'toggle-debug-logging':
      Daemon.applySettings({ debugLogging: Daemon.settings.debugLogging !== null ? null : Daemon.settings.defaultDebugLogging })
      break
    case 'submit-debug-logs':
      Client.startLogUploader()
      break
    case 'open-support-portal':
      Qt.openUrlExternally(BrandHelper.getBrandParam("helpDeskLink"))
      break
    case 'open-blog':
      Qt.openUrlExternally(BrandHelper.getBrandParam("blogLink"))
      break;
    case 'copy-public-ip':
      Clipboard.setText(Daemon.state.externalVpnIp)
      break
    case 'copy-forwarded-port':
      Clipboard.setText(Daemon.state.forwardedPort.toString())
      break
    }
  }
}