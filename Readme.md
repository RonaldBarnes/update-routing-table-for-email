### Update Routing Table for Email

Problem:

A server connected to two ISPs was failing to send email with postfix.

The fibre optic connection was the default, and that ISP blocks port 25 traffic.


Solution:

* Gather list of major email providers (Gmail, Yahoo, etc.)
* Add a list of personal domains as separate file to be included if exists
* `dig` the MX records for the email providers' hosts
* `dig` the IP addresses for those hosts
* Create routing table entries to those IP addresses that travel over the
	ISP that allows it

Routes with higher specificity get used when available, plus there's a priority
flag set in routing table entries.


End result: server's default network connection uses fast fibre optic
connection, but all email notifications use slower cable connection.

