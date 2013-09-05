require 'json'
require 'net/http'
require 'pp'

host_address = 'localhost'
host_port = 8080

@http = Net::HTTP.new(host_address, host_port)


def post_form(path, form_data, headers = { }, http = @http)
  headers['Content-Type'] = 'application/x-www-form-urlencoded'
  request = Net::HTTP::Post.new(path, headers)
  request.set_form_data(form_data)
  http.request(request)
end # post

def post_json(path, data, headers = { }, http = @http)
  headers['Content-Type'] ||= 'application/json'
  request = Net::HTTP::Post.new(path, headers)
  data_as_json = data.is_a?(String) ? data : JSON.pretty_generate(data)
  request.body = data_as_json

  puts "Request Body:\n#{request.body}"

  response = http.request(request)

  parsed_response = case response.content_type
                    when 'application/json'; JSON.parse(response.body)
                    else response.body
                    end
  puts "Response Body:"
  pp parsed_response
  parsed_response
end

node_info_cluster_arguments = {
  'method' => 'node_info_cluster',
  'host' => 'localhost'
}
response = post_json('/api', node_info_cluster_arguments)
pp response

job_submit_arguments = {
    'arguments' => {
        'demo' => true,
        'tasks' => [ '/assets/ee/state_qt_lowres.epitask' ],
        'file-list' => [ '/assets/test.mov' ]
    }
}
response = post_json('/jobs', job_submit_arguments)
pp response

request_id = response['request']['id']
ee_parent_id = response['response']['parent-id']
ee_workflow_ids = response['response']['workflow-ids']

pause_job_arguments_json = {
  'method' => 'job_pause',
  'arguments' => { 'parent-id' => ee_parent_id }
}
response = post_json('/api', pause_job_arguments_json)
pp response

job_status_arguments_json = {
  'method' => 'status_workflows',
  'arguments' => { 'parent-id' => ee_parent_id }
}
response = post_json('/api', job_status_arguments_json)
pp response

pause_job_arguments_json = {
    'method' => 'job_pause',
    'arguments' => { 'parent-id' => ee_parent_id }
}
response = post_json('/api', pause_job_arguments_json)
pp response

resume_job_arguments = {
    'method' => 'job_resume',
    'arguments' => { 'parent-id' => ee_parent_id }
}
response = post_json('/api', resume_job_arguments)
pp response

cancel_job_arguments = {
    'method' => 'job_cancel',
    'arguments' => { 'parent-id' => ee_parent_id }
}
response = post_json('/api', cancel_job_arguments)
pp response

exit

pause_job_arguments = {
  'method' => 'job_pause',
  'arguments' => JSON.generate({ 'parent-id' => ee_parent_id })
}
response = post_form('/api', pause_job_arguments)
pp response

resume_job_arguments = {
  'method' => 'job_resume',
  'arguments' => JSON.generate({ 'parent-id' => ee_parent_id })
}
response = post_form('/api', resume_job_arguments)
pp response

cancel_job_arguments = {
  'method' => 'job_cancel',
  'arguments' => JSON.generate({ 'parent-id' => ee_parent_id })
}
response = post_form('/api', cancel_job_arguments)
pp response
