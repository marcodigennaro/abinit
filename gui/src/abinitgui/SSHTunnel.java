/*--
 SSHTunnel.java - Created in July 2009

 Copyright (c) 2009-2011 Flavio Miguel ABREU ARAUJO.
 Universit� catholique de Louvain, Louvain-la-Neuve, Belgium
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions, and the disclaimer that follows
    these conditions in the documentation and/or other materials
    provided with the distribution.

 3. The names of the author may not be used to endorse or promote
    products derived from this software without specific prior written
    permission.

 In addition, we request (but do not require) that you include in the
 end-user documentation provided with the redistribution and/or in the
 software itself an acknowledgement equivalent to the following:
     "This product includes software developed by the
      Abinit Project (http://www.abinit.org/)."

 THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED.  IN NO EVENT SHALL THE JDOM AUTHORS OR THE PROJECT
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
 USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 For more information on the Abinit Project, please see
 <http://www.abinit.org/>.
 */

package abinitgui;

import com.jcraft.jsch.*;

public class SSHTunnel {

    private Session session;
    private String gatewayuser;
    private String gatewayhost;
    private int gatewayport;
    private int lport;
    private String rhost;
    private int rport;
    MyUserInfo ui;
    private static boolean DEBUG = false;

    private DisplayerJDialog dialog;
    private boolean graphical = false;

    public void setDialog(DisplayerJDialog dialog) {
        graphical = true;
        this.dialog = dialog;
    }

    void printOUT(String str) {
        if (graphical) {
            if (str.endsWith("\n")) {
                dialog.appendOUT(str);
            } else {
                dialog.appendOUT(str + "\n");
            }
        } else {
            if (str.endsWith("\n")) {
                System.out.print(str);
            } else {
                System.out.println(str);
            }
        }
    }

    void printERR(String str) {
        if (graphical) {
            if (str.endsWith("\n")) {
                dialog.appendERR(str);
            } else {
                dialog.appendERR(str + "\n");
            }
        } else {
            if (str.endsWith("\n")) {
                System.err.print(str);
            } else {
                System.err.println(str);
            }
        }
    }

    void printDEB(String str) {
        if (graphical) {
            if (str.endsWith("\n")) {
                dialog.appendDEB(str);
            } else {
                dialog.appendDEB(str + "\n");
            }
        } else {
            if (str.endsWith("\n")) {
                System.out.print(str);
            } else {
                System.out.println(str);
            }
        }
    }

    public SSHTunnel(String gatewayuser, String gatewayhost, int gatewayport, String rhost, int lport, int rport) {
        this.gatewayuser = gatewayuser;
        this.gatewayhost = gatewayhost;
        this.gatewayport = gatewayport;
        this.rhost = rhost;
        this.lport = lport;
        this.rport = rport;
        ui = new MyUserInfo();
    }

    public void setPassword(String pwd) {
        if (ui != null) {
            ui.setPassword(pwd);
        } else {
            printERR("Error in setPassword (ui = null)");
        }
    }

    public int start() {
        try {
            if (DEBUG) {
                JSch.setLogger(new MyLogger());
            }
            JSch jsch = new JSch();
            session = jsch.getSession(gatewayuser, gatewayhost, gatewayport);

            // username and password will be given via UserInfo interface.
            session.setUserInfo(ui);
            session.connect();

            int assinged_port = session.setPortForwardingL(lport, rhost, rport);
            // TODO afficher ce message sur une fenêtre !
            printDEB("localhost:" + assinged_port + " -> " + rhost + ":" + rport);
            return assinged_port;
        } catch (Exception e) {
            printERR(e.getMessage());
            return -1;
        }
    }

    public void stop() {
        try {
            session.disconnect();
        } catch (Exception e) {
            printERR(e.getMessage());
        }
    }
}
